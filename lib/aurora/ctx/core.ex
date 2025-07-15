defmodule Aurora.Ctx.Core do
  @moduledoc """
  Core implementation of common database operations using Ecto.

  Provides functions for:
  - CRUD operations (create, read, update, delete)
  - Pagination (list_paginated, navigation)
  - Query operations (count, list) with filtering, sorting, and preloading
  - Record management (change, new)
  - Query building and clause exclusion
  """

  import Ecto.Query
  alias Aurora.Ctx.Pagination
  alias Aurora.Ctx.QueryBuilder

  @default_paginate Application.compile_env(:aurora_ctx, :paginate, %{})

  @doc """
  Lists all records for a schema with optional filtering and sorting.

  ## Parameters
  - repo_module (module()) - Ecto.Repo module to use
  - schema_module (module()) - Schema module to query
  - opts (keyword()) - Optional query parameters (see `Aurora.Ctx.QueryBuilder` for available options)

  ## Returns
  - list(Ecto.Schema.t())

  ## Examples

      alias MyApp.{Repo, Product}
      Core.list(Repo, Product)
      #=> [%Product{}, ...]

      Core.list(Repo, Product,
        where: [status: :active],
        order_by: [desc: :inserted_at],
        preload: [:category]
      )
      #=> [%Product{category: %Category{}}, ...]
  """
  @spec list(module(), module(), keyword()) :: list()
  def list(repo_module, schema_module, opts \\ []) do
    schema_module
    |> from()
    |> QueryBuilder.options(opts)
    |> repo_module.all()
  end

  @doc """
  Lists records with pagination support.

  ## Parameters
  - repo_module (module()) - Ecto.Repo module to use
  - schema_module (module()) - Schema module to query
  - opts (keyword()) - See `Aurora.Ctx.QueryBuilder` for available query options.

  ## Configuration

  Default pagination settings can be configured in your `config.exs`:

      config :aurora_ctx, :pagination,
        page: 1,
        per_page: 40

  If not configured, defaults to page: 1, per_page: 40.
  Page navigation is safe - attempting to navigate beyond valid pages will return
  the current page unchanged.

  ## Returns
  - `Aurora.Ctx.Pagination` struct.

  ## Examples

      alias MyApp.{Repo, Product}
      Core.list_paginated(Repo, Product,
        paginate: %{page: 1, per_page: 20},
        where: [category_id: 1],
        order_by: [desc: :inserted_at]
      )
      #=> %Aurora.Ctx.Pagination{
      #=>   entries: [%Product{}],
      #=>   page: 1,
      #=>   per_page: 20,
      #=>   entries_count: 50,
      #=>   pages_count: 3
      #=> }
  """
  @spec list_paginated(module(), module(), keyword()) :: Pagination.t()
  def list_paginated(repo_module, schema_module, opts \\ []) do
    paginate =
      opts
      |> Keyword.get(:paginate, @default_paginate)
      |> Pagination.new()

    entries_count = count(repo_module, schema_module, opts)
    pages_count = ceil(entries_count / paginate.per_page)
    new_opts = Keyword.put(opts, :paginate, paginate)

    struct(
      paginate,
      %{
        repo_module: repo_module,
        schema_module: schema_module,
        entries_count: entries_count,
        pages_count: pages_count,
        opts: opts,
        entries: list(repo_module, schema_module, new_opts)
      }
    )
  end

  @doc """
  Changes to a specific page in paginated results.

  Parameters:
    - paginate (Aurora.Ctx.Pagination.t()) - Current pagination state
    - page (integer) - Target page number. If the requested page is out of range
      (< 1 or > pages_count), returns the current page unchanged.

  Example:
      paginate = list_products_paginated(per_page: 20)
      page5 = to_page(paginate, 5)  # Jumps directly to page 5

      # Out of range page results in no change
      page5 = to_page(paginate, 999) # Returns current page if 999 > pages_count

  Returns:
    - Aurora.Ctx.Pagination struct with entries for the target page, or unchanged
      if the target page is out of range.
  """
  @spec to_page(Pagination.t() | map, integer) :: Pagination.t()
  def to_page(
        %Pagination{
          repo_module: repo_module,
          schema_module: schema_module,
          pages_count: pages_count
        } = paginate,
        page
      )
      when page >= 1 and page <= pages_count do
    opts = Keyword.put(paginate.opts, :paginate, %{page: page, per_page: paginate.per_page})

    Map.merge(paginate, %{page: page, entries: list(repo_module, schema_module, opts)})
  end

  def to_page(paginate, _page), do: paginate

  @doc """
  Moves to next page in paginated results.

  Parameters:
    - paginate (Aurora.Ctx.Pagination.t()) - Current pagination state containing
      entries, page number, and other metadata. If already on the last page,
      returns the current page unchanged.

  Example:
      paginate = list_products_paginated(per_page: 20)
      next_page = next_page(paginate) # Moves to page 2
  """
  @spec next_page(Pagination.t() | map) :: Pagination.t()
  def next_page(%Pagination{page: page} = paginate), do: to_page(paginate, page + 1)

  @doc """
  Moves to previous page in paginated results.

  Parameters:
    - paginate (Aurora.Ctx.Pagination.t()) - Current pagination state containing
      entries, page number, and other metadata. If already on page 1,
      returns the first page unchanged.

  Example:
      paginate = list_products_paginated(page: 2, per_page: 20)
      prev_page = previous_page(paginate) # Moves back to page 1
  """
  @spec previous_page(Pagination.t() | map) :: Pagination.t()
  def previous_page(%Pagination{page: page} = paginate), do: to_page(paginate, page - 1)

  @doc """
  Counts total records matching query conditions.

  Parameters:
  - repo_module (module) - Ecto.Repo to use
  - schema_module (module) - Schema to query
  - opts (keyword) - Optional query filtering options

  Returns total count of matching records.
  """
  @spec count(module(), module(), keyword()) :: non_neg_integer()
  def count(repo_module, schema_module, opts \\ []) do
    schema_module
    |> from()
    |> QueryBuilder.options(opts)
    |> exclude_clauses([:select, :limit, :offset, :order_by])
    |> repo_module.aggregate(:count)
  end

  @doc """
  Creates a new record.

  Parameters:
  - repo_module (module()) - Ecto.Repo to use
  - schema_module (module() | ) - Schema to create
  - attrs (map()) - Attributes for the new record

  Returns {:ok, schema} on success, {:error, changeset} on failure.
  """
  @spec create(module(), module() | Ecto.Changeset.t(), map() | nil) ::
          {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def create(repo_module, schema_module_or_changeset, %{} = attrs),
    do: create(repo_module, schema_module_or_changeset, :changeset, attrs)

  @doc """
  Creates a new record with optional custom changeset function.

  ## Parameters
  - repo_module (module()) - Ecto.Repo module to use
  - schema_module (module() | Ecto.Changeset.t()) - Schema module for the record
  - changeset_function (atom()) - Custom changeset function to use
  - attrs (map()) - Attributes for the new record

  ## Returns
  - `{:ok, Ecto.Schema.t()}` - On success
  - `{:error, Ecto.Changeset.t()}` - On validation failure

  ## Examples

      alias MyApp.{Repo, Product}
      Core.create(Repo, Product, %{name: "Widget"})
      #=> {:ok, %Product{name: "Widget"}}

      Core.create(Repo, Product, :custom_changeset, %{
        name: "Widget",
        status: "active"
      })
      #=> {:ok, %Product{name: "Widget", status: "active"}}
  """
  @spec create(module(), module() | Ecto.Changeset.t(), atom(), map() | nil) ::
          {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}

  def create(
        repo_module,
        schema_module_or_changeset,
        changeset_function \\ :changeset,
        attrs \\ %{}
      )

  def create(repo_module, %Ecto.Changeset{} = changeset, changeset_function, attrs) do
    changeset
    |> then(&apply(&1.data.__struct__, changeset_function, [&1, attrs]))
    |> repo_module.insert()
  end

  def create(repo_module, schema_module, changeset_function, attrs) do
    schema_module.__struct__()
    |> then(&apply(schema_module, changeset_function, [&1, attrs]))
    |> repo_module.insert()
  end

  @doc """
  Creates a new record, raising on errors.

  Parameters:
  - repo_module (module()) - Ecto.Repo to use
  - schema_module_or_changeset (module() | Ecto.Changeset.t()) - Schema to create
  - attrs (map()) - Attributes for the new record

  Returns created schema or raises on error.
  """
  @spec create!(module(), module() | Ecto.Changeset.t(), map() | nil) :: Ecto.Schema.t()
  def create!(repo_module, schema_module_or_changeset, %{} = attrs),
    do: create!(repo_module, schema_module_or_changeset, :changeset, attrs)

  @doc """
  Creates a new record, raising on errors.

  Parameters:
  - repo_module (module) - Ecto.Repo to use
  - schema_module_or_changeset (module | Ecto.Changeset) - Schema to create
  - changeset_function (atom) - Changeset function to use
  - attrs (map) - Attributes for the new record

  Returns created schema or raises on error.
  """
  @spec create!(module(), module() | Ecto.Changeset.t(), atom(), map() | nil) :: Ecto.Schema.t()
  def create!(
        repo_module,
        schema_module_or_changeset,
        changeset_function \\ :changeset,
        attrs \\ %{}
      )

  def create!(repo_module, %Ecto.Changeset{} = changeset, changeset_function, attrs) do
    changeset
    |> then(&apply(&1.data.__struct__, changeset_function, [&1, attrs]))
    |> repo_module.insert!()
  end

  def create!(repo_module, schema_module, changeset_function, attrs) do
    schema_module.__struct__()
    |> then(&apply(schema_module, changeset_function, [&1, attrs]))
    |> repo_module.insert!()
  end

  @doc """
  Gets a record by id.

  Parameters:
  - repo_module (module) - Ecto.Repo to use
  - schema_module (module) - Schema to query
  - id (term) - Primary key to look up
  - opts (keyword) - Optional query parameters

  Returns found schema or nil if not found.
  """
  @spec get(module(), module(), term(), keyword()) :: Ecto.Schema.t() | nil
  def get(repo_module, schema_module, id, opts \\ []) do
    schema_module
    |> from()
    |> QueryBuilder.options(opts)
    |> repo_module.get(id)
  end

  @doc """
  Gets a record by id, raising if not found.

  Parameters:
  - repo_module (module) - Ecto.Repo to use
  - schema_module (module) - Schema to query
  - id (term) - Primary key to look up
  - opts (keyword) - Optional query parameters

  Returns found schema or raises Ecto.NoResultsError.
  """
  @spec get!(module(), module(), term(), keyword()) :: Ecto.Schema.t()
  def get!(repo_module, schema_module, id, opts \\ []) do
    schema_module
    |> from()
    |> QueryBuilder.options(opts)
    |> repo_module.get!(id)
  end

  @doc """
  Gets a record by filtering clauses.

  Parameters:
  - repo_module (module) - Ecto.Repo to use
  - schema_module (module) - Schema to query
  - clauses (keyword) - Clauses for getting the element
  - opts (keyword) - Optional query parameters

  Returns found schema or nil if not found.
  """
  @spec get_by(module(), module(), keyword(), keyword()) :: Ecto.Schema.t()
  def get_by(repo_module, schema_module, clauses, opts \\ []) do
    schema_module
    |> from()
    |> QueryBuilder.options(opts)
    |> repo_module.get_by(clauses)
  end

  @doc """
  Gets a record by filtering clauses.

  Parameters:
  - repo_module (module) - Ecto.Repo to use
  - schema_module (module) - Schema to query
  - clauses (keyword) - Clauses for getting the element
  - opts (keyword) - Optional query parameters

  Returns found schema or raises Ecto.NoResultsError.
  """
  @spec get_by!(module(), module(), keyword(), keyword()) :: Ecto.Schema.t()
  def get_by!(repo_module, schema_module, clauses, opts \\ []) do
    schema_module
    |> from()
    |> QueryBuilder.options(opts)
    |> repo_module.get_by!(clauses)
  end

  @doc """
  Deletes the given entity.

  Parameters:
  - repo_module (module): The Ecto.Repo module to use
  - entity (Ecto.Schema.t()): The entity to delete

  Returns: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  """
  @spec delete(module(), Ecto.Schema.t()) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def delete(repo_module, entity), do: repo_module.delete(entity)

  @doc """
  Deletes the given entity, raising on errors.

  Parameters:
  - repo_module (module): The Ecto.Repo module to use
  - entity (Ecto.Schema.t()): The entity to delete

  Returns: Ecto.Schema.t()
  Raises: Ecto.StaleEntryError
  """
  @spec delete!(module(), Ecto.Schema.t()) :: Ecto.Schema.t()
  def delete!(repo_module, entity), do: repo_module.delete!(entity)

  @doc """
  Updates an entity with given attributes.

  Parameters:
  - repo_module (module) - Ecto.Repo to use
  - entity_or_changeset (Ecto.Schema.t() | Ecto.Changeset.t()) - Entity to update or changeset to apply
  - attrs (map) - Update attributes

  Returns {:ok, schema} on success, {:error, changeset} on failure.
  """
  @spec update(module(), Ecto.Schema.t() | Ecto.Changeset.t(), map() | nil) ::
          {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}

  def update(repo_module, entity_or_changeset, %{} = attrs),
    do: update(repo_module, entity_or_changeset, :changeset, attrs)

  @doc """
  Updates an entity using a specific changeset function.

  ## Parameters
  - repo_module (module()) - Ecto.Repo module to use
  - entity_or_changeset (Ecto.Schema.t() | Ecto.Changeset.t()) - Existing record to update
  - changeset_function (atom()) - Custom changeset function
  - attrs (map()) - Update attributes

  ## Returns
  - `{:ok, Ecto.Schema.t()}` - On success
  - `{:error, Ecto.Changeset.t()}` - On validation failure

  ## Examples

      alias MyApp.{Repo, Product}
      product = %Product{name: "Old Name"}
      Core.update(Repo, product, %{name: "New Name"})
      #=> {:ok, %Product{name: "New Name"}}
  """
  @spec update(module(), Ecto.Schema.t() | Ecto.Changeset.t(), atom(), map() | nil) ::
          {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def update(repo_module, entity_or_changeset, changeset_function \\ :changeset, attrs \\ %{})

  def update(repo_module, %Ecto.Changeset{} = changeset, changeset_function, attrs) do
    changeset
    |> then(&apply(changeset.data.__struct__, changeset_function, [&1, attrs]))
    |> repo_module.update()
  end

  def update(repo_module, entity, changeset_function, attrs) do
    entity
    |> then(&apply(entity.__struct__, changeset_function, [&1, attrs]))
    |> repo_module.update()
  end

  @doc """
  Creates a changeset for the given entity.

  Parameters:
  - entity_or_changeset (Ecto.Schema.t() | Ecto.Changeset.t()) - Entity for changeset
  - attrs (map) - Changeset attributes

  Returns Ecto.Changeset.
  """
  @spec change(Ecto.Schema.t() | Ecto.Changeset.t(), map() | nil) :: Ecto.Changeset.t()
  def change(entity_or_changeset, %{} = attrs), do: change(entity_or_changeset, :changeset, attrs)

  @doc """
  Creates a changeset for the given entity using a specific changeset function.

  ## Parameters
  - entity_or_changeset (Ecto.Schema.t() | Ecto.Changeset.t()) - Existing record or changeset
  - changeset_function (atom()) - Custom changeset function
  - attrs (map()) - Changeset attributes

  ## Returns
  - Ecto.Changeset.t()

  ## Examples

      alias MyApp.Product
      product = %Product{name: "Widget"}
      Core.change(product, %{name: "New Widget"})
      #=> #Ecto.Changeset<changes: %{name: "New Widget"}>

      Core.change(product, :custom_changeset, %{status: "active"})
      #=> #Ecto.Changeset<changes: %{status: "active"}>
  """
  @spec change(Ecto.Schema.t() | Ecto.Changeset.t(), atom(), map() | nil) :: Ecto.Changeset.t()
  def change(entity_or_changeset, changeset_function \\ :changeset, attrs \\ %{})

  def change(%Ecto.Changeset{} = changeset, changeset_function, attrs) do
    apply(changeset.data.__struct__, changeset_function, [changeset, attrs])
  end

  def change(entity, changeset_function, attrs) do
    apply(entity.__struct__, changeset_function, [entity, attrs])
  end

  @doc """
  Initializes a new schema struct with optional attributes or options.

  ## Parameters
  - repo_module (module) - Ecto.Repo to use
  - schema_module (module) - Schema to initialize
  - attrs_or_opts - One of:
    - map: Initial attributes (will use empty options)
    - keyword list: Options (will use empty attributes)

  Returns initialized schema struct.
  """
  @spec new(module(), module(), map() | keyword()) :: Ecto.Schema.t()
  def new(repo_module, schema_module, %{} = attrs), do: new(repo_module, schema_module, attrs, [])

  def new(repo_module, schema_module, opts) when is_list(opts),
    do: new(repo_module, schema_module, %{}, opts)

  @doc """
  Initializes a new struct with optional preloads.

  Parameters:
  - repo_module (module): The Ecto.Repo module to use
  - schema_module (module): The Ecto.Schema module to initialize
  - opts (keyword): Optional preload parameters

  Returns: Ecto.Schema.t()
  """
  @spec new(module(), module(), map(), keyword()) :: Ecto.Schema.t()
  def new(repo_module, schema_module, attrs \\ %{}, opts \\ []) do
    attrs
    |> schema_module.__struct__()
    |> repo_preload(repo_module, opts[:preload])
  end

  @doc """
  Excludes query clauses from an Ecto query.

  Parameters:
  - query (Ecto.Query.t()) - Query to modify
  - clauses (atom | [atom]) - Clause(s) to exclude. Available clauses:
    - :where - WHERE conditions
    - :select - SELECT clauses
    - :order_by - ORDER BY clauses
    - :group_by - GROUP BY clauses
    - :having - HAVING conditions
    - :limit - LIMIT clause
    - :offset - OFFSET clause
    - :preload - Preload associations
    - :lock - Lock clauses

  Returns modified query.

  ## Examples

      query = from(p in Product)
      exclude_clauses(query, :where)
      exclude_clauses(query, [:select, :order_by])
  """
  @spec exclude_clauses(Ecto.Query.t(), atom() | list(atom())) :: Ecto.Query.t()
  def exclude_clauses(query, clauses) when is_list(clauses) do
    Enum.reduce(clauses, query, &Ecto.Query.exclude(&2, &1))
  end

  def exclude_clauses(query, clause) when is_atom(clause), do: Ecto.Query.exclude(query, clause)

  @spec repo_preload(Ecto.Schema.t(), module(), keyword()) :: Ecto.Schema.t()
  defp repo_preload(entity, _repo_module, nil), do: entity
  defp repo_preload(entity, repo_module, preload), do: repo_module.preload(entity, preload)
end
