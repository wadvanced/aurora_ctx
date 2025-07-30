defmodule Aurora.Ctx.QueryBuilder do
  @moduledoc """
  Provides functions for building and composing Ecto queries with common operations like filtering,
  sorting, pagination, and preloading associations.
  """

  import Ecto.Query

  alias Ecto.Query.DynamicExpr

  @sort_directions [
    :asc,
    :asc_nulls_last,
    :asc_nulls_first,
    :desc,
    :desc_nulls_last,
    :desc_nulls_first
  ]

  @doc """
  Applies a list of query options to an Ecto query.

  ## Parameters
  - query (Ecto.Query.t() | nil) - Core query to modify
  - options (keyword) - List of query options to apply

  ## Options
  - :preload (atom | list) - Associations to preload
  - :where (keyword | map | tuple) - Filter conditions
    - Simple equality: `{:field, value}`
    - Comparison: `{:field, operator, value}` where operator can be:
      - :greater_than, :gt - Greater than
      - :greater_equal_than, :ge - Greater than or equal
      - :less_than, :lt - Less than
      - :less_equal_than, :le - Less than or equal
      - :equal_to, :eq - Equal to
      - :like - Comparison string where the '%' represents any number of characters,
          and the '_' represents any single character.
      - :ilike - Similar to like, but ignores characters cases during comparison.
    - Range: `{:field, :between, start_value, end_value}`
    - Dynamic query: dynamic([p], p.reference == "item_001" or p.reference == "item_003")
  - :or_where (keyword | map | tuple) - Same as :where but combines with OR
  - :paginate (map) - Pagination options with keys:
    - :page (integer) - Page number
    - :per_page (integer) - Items per page
  - :order_by (atom | tuple | list) - Sorting options:
    - field (atom | {:asc | :desc, field}) - Field to sort by ascending
    - fields ([{:asc | :desc, field}]) - List of sort fields specifications

  ## Returns
  - Ecto.Query.t() - Modified query with all options applied

  ## Examples
      query = from(p in Product)
      QueryBuilder.options(query,
        where: [status: :active],
        preload: [:category],
        order_by: [desc: :inserted_at],
        paginate: %{page: 1, per_page: 20}
      )

  For more advanced query examples including filtering, sorting, and associations,
  see the [Query Usage Guide](examples.html#query-usage).
  """
  @spec options(Ecto.Query.t() | nil, keyword) :: Ecto.Query.t()
  def options(query, options \\ [])
  def options(nil, _options), do: nil

  def options(query, options) when is_list(options) do
    Enum.reduce(options, query, &option(&2, &1))
  end

  ## PRIVATE

  @spec option(Ecto.Query.t(), tuple) :: Ecto.Query.t()
  defp option(%Ecto.Query{} = query, {:preload, preload}),
    do: preload(query, ^preload)

  defp option(%Ecto.Query{} = query, {:where, conditions})
       when is_list(conditions) or is_non_struct_map(conditions) do
    Enum.reduce(conditions, query, &where_condition/2)
  end

  defp option(%Ecto.Query{} = query, {:where, condition}) do
    where_condition(condition, query)
  end

  defp option(%Ecto.Query{} = query, {:or_where, conditions})
       when is_list(conditions) or is_non_struct_map(conditions) do
    Enum.reduce(conditions, query, &or_where_condition/2)
  end

  defp option(%Ecto.Query{} = query, {:or_where, condition}) do
    or_where_condition(condition, query)
  end

  defp option(%Ecto.Query{} = query, {:paginate, %{page: page, per_page: per_page}})
       when is_integer(page) and is_integer(per_page) do
    offset = (page - 1) * per_page

    from(q in query,
      limit: ^per_page,
      offset: ^offset
    )
  end

  defp option(%Ecto.Query{} = query, {:order_by, fields}) when is_list(fields) do
    Enum.reduce(fields, query, fn
      {direction, field}, acc when direction in @sort_directions ->
        from(q in acc, order_by: [{^direction, ^field}])

      field, acc when is_atom(field) ->
        from(q in acc, order_by: [asc: ^field])
    end)
  end

  defp option(%Ecto.Query{} = query, {:order_by, {direction, field}})
       when direction in [:asc, :desc] do
    from(q in query, order_by: [{^direction, ^field}])
  end

  defp option(%Ecto.Query{} = query, {:order_by, field}) when is_atom(field) do
    from(q in query, order_by: [asc: ^field])
  end

  defp option(query, _option), do: query

  @spec where_condition(tuple() | Macro.t(), Ecto.Query.t()) :: Ecto.Query.t()
  defp where_condition(%DynamicExpr{} = expression, query), do: from(query, where: ^expression)

  defp where_condition({field, value}, query),
    do: from(q in query, where: field(q, ^field) == ^value)

  defp where_condition({field, comparator, value}, query) when comparator in [:greater_than, :gt],
    do: from(q in query, where: field(q, ^field) > ^value)

  defp where_condition({field, comparator, value}, query)
       when comparator in [:greater_equal_than, :ge],
       do: from(q in query, where: field(q, ^field) >= ^value)

  defp where_condition({field, comparator, value}, query) when comparator in [:less_than, :lt],
    do: from(q in query, where: field(q, ^field) < ^value)

  defp where_condition({field, comparator, value}, query)
       when comparator in [:less_equal_than, :le],
       do: from(q in query, where: field(q, ^field) <= ^value)

  defp where_condition({field, comparator, value}, query) when comparator in [:equal_to, :eq],
    do: from(q in query, where: field(q, ^field) == ^value)

  defp where_condition({field, :like, value}, query),
    do: from(q in query, where: q |> field(^field) |> like(^value))

  defp where_condition({field, :ilike, value}, query),
    do: from(q in query, where: q |> field(^field) |> ilike(^value))

  defp where_condition({field, :between, start_value, end_value}, query),
    do:
      from(q in query, where: field(q, ^field) >= ^start_value and field(q, ^field) <= ^end_value)

  defp where_condition(_where_condition, query), do: query

  @spec or_where_condition(tuple() | Macro.t(), Ecto.Query.t()) :: Ecto.Query.t()
  defp or_where_condition(%DynamicExpr{} = expression, query), do: from(query, where: ^expression)

  defp or_where_condition({field, value}, query),
    do: from(q in query, or_where: field(q, ^field) == ^value)

  defp or_where_condition({field, comparator, value}, query)
       when comparator in [:greater_than, :gt],
       do: from(q in query, or_where: field(q, ^field) > ^value)

  defp or_where_condition({field, comparator, value}, query)
       when comparator in [:greater_equal_than, :ge],
       do: from(q in query, or_where: field(q, ^field) >= ^value)

  defp or_where_condition({field, comparator, value}, query) when comparator in [:less_than, :lt],
    do: from(q in query, or_where: field(q, ^field) < ^value)

  defp or_where_condition({field, comparator, value}, query)
       when comparator in [:less_equal_than, :le],
       do: from(q in query, or_where: field(q, ^field) <= ^value)

  defp or_where_condition({field, comparator, value}, query) when comparator in [:equal_to, :eq],
    do: from(q in query, or_where: field(q, ^field) == ^value)

  defp or_where_condition({field, :like, value}, query),
    do: from(q in query, or_where: q |> field(^field) |> like(^value))

  defp or_where_condition({field, :ilike, value}, query),
    do: from(q in query, or_where: q |> field(^field) |> ilike(^value))

  defp or_where_condition({field, :between, start_value, end_value}, query),
    do:
      from(q in query,
        or_where: field(q, ^field) >= ^start_value and field(q, ^field) <= ^end_value
      )

  defp or_where_condition(_or_where_condition, query), do: query
end
