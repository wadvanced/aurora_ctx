defmodule Aurora.Ctx.QueryBuilder do
  @moduledoc """
  Provides functions for building and composing Ecto queries with common operations like filtering,
  sorting, pagination, and preloading associations.

  ## Key Features

  - **Flexible filtering**: Support for equality, comparison operators, ranges, and dynamic expressions
  - **Pagination**: Built-in offset/limit pagination with page and per_page parameters
  - **Sorting**: Multiple sort directions including null handling options
  - **Association preloading**: Efficient loading of related data
  - **Field selection**: Control which fields are returned from queries

  ## Supported Filter Operations

  - Equality: `{:field, value}`
  - Comparisons: `:gt`, `:ge`, `:lt`, `:le`, `:eq`
  - Pattern matching: `:like`, `:ilike`
  - Range queries: `:between`
  - Dynamic expressions for complex logic

  ## Examples

  ```elixir
  # Basic filtering and sorting
  query = from(p in Product)
  QueryBuilder.options(query,
    where: [status: :active, {:price, :gt, 100}],
    order_by: [desc: :inserted_at],
    preload: [:category]
  )

  # Pagination with multiple conditions
  QueryBuilder.options(query,
    where: [
      status: :active,
      {:price, :between, 50, 200},
      {:name, :ilike, "%phone%"}
    ],
    paginate: %{page: 2, per_page: 10},
    select: [:id, :name, :price]
  )

  # Using dynamic expressions
  dynamic_filter = dynamic([p], p.category_id in ^category_ids)
  QueryBuilder.options(query,
    where: ^dynamic_filter,
    select: [:id, :name, :price]
  )
  ```
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
  Applies query options to an Ecto query.

  ## Parameters

  - `query` (`Ecto.Query.t()` | `nil`) - Base query to modify
  - `options` (`keyword()`) - Options to apply (see below)

  ## Options

  ### Filtering
  - `:where` - Conditions to filter by (AND logic):
    - Simple equality: `{:field, value}`
    - Comparison operators:
      - `:greater_than`, `:gt` - Greater than
      - `:greater_equal_than`, `:ge` - Greater than or equal
      - `:less_than`, `:lt` - Less than
      - `:less_equal_than`, `:le` - Less than or equal
      - `:equal_to`, `:eq` - Equal to
      - `:like` - Pattern matching with `%` (any chars) and `_` (single char)
      - `:ilike` - Case-insensitive pattern matching
    - Range operator:
      - `:between` - Value should be within a start/end range
    - Dynamic queries:
      - `dynamic(bindings, query_expression)` - Can be used to build complex queries

  - `:or_where` - Same as `:where` but with OR logic

  ### Sorting
  - `:order_by` - Sorting specification:
    - Single field: `:name`
    - Direction: `{:desc, :inserted_at}`
    - Multiple: `[asc: :name, desc: :price]`

  ### Pagination
  - `:paginate` (`map()`) - Pagination options with keys:
    - `:page` (`integer()`) - Page number (1-based)
    - `:per_page` (`integer()`) - Items per page

  ### Data Selection
  - `:select` - Fields to return:
    - Single: `:id`
    - List: `[:id, :name]`
    - Dynamic: `^dynamic_expr`

  - `:preload` - Associations to load:
    - Single: `:author`
    - Nested: `[author: [:company]]`

  ## Returns

  `Ecto.Query.t()` | `nil` - Modified query or nil if input was nil

  """
  @spec options(Ecto.Query.t() | nil, keyword()) :: Ecto.Query.t() | nil
  def options(query, options \\ [])
  def options(nil, _options), do: nil

  def options(query, options) when is_list(options) do
    Enum.reduce(options, query, &option(&2, &1))
  end

  ## PRIVATE

  # Applies a single query option to the given query
  @spec option(Ecto.Query.t(), tuple()) :: Ecto.Query.t()
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

  defp option(%Ecto.Query{} = query, {:select, fields}) when is_list(fields) do
    from(query, select: ^fields)
  end

  defp option(%Ecto.Query{} = query, {:select, field}) when is_atom(field) do
    fields = [field]
    from(query, select: ^fields)
  end

  defp option(%Ecto.Query{} = query, {:select, %DynamicExpr{} = expression}) do
    from(query, select: ^expression)
  end

  defp option(query, _option), do: query

  # Applies a WHERE condition to the query based on the condition type
  @spec where_condition(tuple() | Ecto.Query.dynamic_expr(), Ecto.Query.t()) :: Ecto.Query.t()
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

  # Applies an OR WHERE condition to the query based on the condition type
  @spec or_where_condition(tuple() | Ecto.Query.dynamic_expr(), Ecto.Query.t()) :: Ecto.Query.t()
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
