defmodule Aurora.Ctx.Core do
  @moduledoc """
  Provides comprehensive database operations using Ecto with advanced query building,
  pagination, and CRUD functionality.

  This module serves as the core interface for database operations, offering:

  - **CRUD Operations**: Create, read, update, and delete records with flexible
    changeset support
  - **Advanced Pagination**: Navigate through large datasets with configurable
    page sizes and safe boundary handling
  - **Query Building**: Filter, sort, and preload associations using
    `Aurora.Ctx.QueryBuilder` options
  - **Record Management**: Initialize new records and build changesets with
    custom functions
  - **Query Utilities**: Count records and exclude specific query clauses

  ## Configuration

  Default pagination settings can be configured in your application:

  ```elixir
  config :aurora_ctx, :paginate,
    page: 1,
    per_page: 40
  ```

  ## Query Options

  Most functions accept query options that are processed by `Aurora.Ctx.QueryBuilder`:

  - `where: keyword()` - Filter conditions
  - `order_by: keyword()` - Sorting specifications
  - `preload: atom() | list()` - Associations to preload
  - `paginate: map()` - Pagination parameters
  - `select: list()` - List of fields to load

  ## Examples

  ```elixir
  alias MyApp.{Repo, Product, Category}

  # List all products with filtering and preloading
  products = Core.list(Repo, Product,
    where: [status: :active],
    order_by: [desc: :inserted_at],
    preload: [:category]
  )

  # Paginated listing with navigation
  page1 = Core.list_paginated(Repo, Product,
    paginate: %{page: 1, per_page: 20},
    where: [category_id: 1]
  )

  page2 = Core.next_page(page1)

  # CRUD operations
  {:ok, product} = Core.create(Repo, Product, %{name: "Widget", price: 99.99})
  {:ok, updated} = Core.update(Repo, product, %{price: 89.99})
  {:ok, _deleted} = Core.delete(Repo, updated)
  ```
  """

  import Ecto.Query
  alias Aurora.Ctx.Pagination
  alias Aurora.Ctx.QueryBuilder

  @default_paginate Application.compile_env(:aurora_ctx, :paginate, %{})

  @doc """
  Lists all records for a schema with optional filtering and sorting.

  ## Parameters

  - `repo_module` (module()) - Ecto.Repo module to use for database operations
  - `schema_module` (module()) - Schema module to query
  - `opts` (keyword()) - Query options processed by `Aurora.Ctx.QueryBuilder`:
    - `where: keyword()` - Filter conditions
    - `order_by: keyword()` - Sorting specifications
    - `preload: atom() | list()` - Associations to preload
    - `select: list()` - List of fields to load

  ## Returns

  `list(Ecto.Schema.t())` - List of records as schema structs matching the query conditions

  ## Examples

  ```elixir
  alias MyApp.{Repo, Product}

  # List all products
  Core.list(Repo, Product)
  #=> [%Product{}, ...]

  # List with filtering, sorting, and preloading
  Core.list(Repo, Product,
    where: [status: :active],
    order_by: [desc: :inserted_at],
    preload: [:category]
  )
  #=> [%Product{category: %Category{}}, ...]
  ```
  """
  @spec list(module(), module(), keyword()) :: list(Ecto.Schema.t())
  def list(repo_module, schema_module, opts \\ []) do
    schema_module
    |> from()
    |> QueryBuilder.options(opts)
    |> repo_module.all()
  end

  @doc """
  Lists records with pagination metadata.

  Returns a `Pagination` struct containing the current page entries along with
  metadata for browsing. Page boundaries are safely handled - attempting to
  navigate beyond valid pages returns the current page with its entries refreshed.

  ## Parameters

  - `repo_module` (module()) - Ecto.Repo module to use for database operations
  - `schema_module` (module()) - Schema module to query
  - `opts` (keyword()) - Query and pagination options:
    - `paginate: map()` - Pagination configuration with `page` and `per_page` keys
    - Plus all options supported by `Aurora.Ctx.QueryBuilder`

  ## Returns

  `Aurora.Ctx.Pagination.t()` - Pagination struct, see `Aurora.Ctx.Pagination`

  ## Examples

  ```elixir
  alias MyApp.{Repo, Product}

  # Basic pagination
  page1 = Core.list_paginated(Repo, Product,
    paginate: %{page: 1, per_page: 20}
  )
  #=> %Aurora.Ctx.Pagination{
  #=>   entries: [%Product{}],
  #=>   page: 1,
  #=>   per_page: 20,
  #=>   entries_count: 150,
  #=>   pages_count: 8
  #=> }

  # With filtering and sorting
  Core.list_paginated(Repo, Product,
    paginate: %{page: 2, per_page: 10},
    where: [category_id: 1],
    order_by: [desc: :inserted_at]
  )
  ```
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
  Navigates to a specific page in paginated results.

  Provides safe navigation by validating the target page is within valid bounds.
  If the requested page is out of range (< 1 or > pages_count), returns the
  current pagination state with its entries updated.

  ## Parameters

  - `paginate` (Aurora.Ctx.Pagination.t()) - Current pagination state containing
    repo module, schema, and query options
  - `page` (integer()) - Target page number to navigate to

  ## Returns

  `Aurora.Ctx.Pagination.t()` - Updated pagination struct with entries for the
  target page

  ## Examples

  ```elixir
  paginate = Core.list_paginated(Repo, Product, paginate: %{per_page: 20})

  # Navigate to page 5
  page5 = Core.to_page(paginate, 5)
  #=> %Aurora.Ctx.Pagination{page: 5, entries: [...]}

  # Out of range navigation returns current page with its entries updated
  same_page = Core.to_page(paginate, 999)
  #=> %Aurora.Ctx.Pagination{page: 1, entries: [...]} (unchanged)
  ```
  """
  @spec to_page(Pagination.t(), integer()) :: Pagination.t()
  def to_page(
        %Pagination{
          repo_module: repo_module,
          schema_module: schema_module,
          pages_count: pages_count
        } = paginate,
        page
      )
      when page >= 1 and page <= pages_count do
    opts =
      paginate.opts
      |> Keyword.get(:paginate, %{})
      |> Map.put_new(:per_page, paginate.per_page)
      |> Map.put(:page, page)
      |> then(&Keyword.put(paginate.opts, :paginate, &1))

    Map.merge(paginate, %{page: page, entries: list(repo_module, schema_module, opts)})
  end

  def to_page(
        %Pagination{
          repo_module: repo_module,
          schema_module: schema_module,
          opts: opts
        } = paginate,
        _page
      ) do
    opts =
      Keyword.put(opts, :paginate, %{per_page: paginate.per_page, page: paginate.page})

    Map.merge(paginate, %{entries: list(repo_module, schema_module, opts)})
  end

  @doc """
  Moves to the next page in paginated results.

  Safely advances to the next page if available. If already on the last page,
  returns the current pagination state with its entries refreshed.

  ## Parameters

  - `paginate` (Aurora.Ctx.Pagination.t()) - Current pagination state

  ## Returns

  `Aurora.Ctx.Pagination.t()` - Pagination struct for the next page or current
  page if already at the end

  ## Examples

  ```elixir
  page1 = Core.list_paginated(Repo, Product, paginate: %{page: 1, per_page: 20})
  page2 = Core.next_page(page1)
  #=> %Aurora.Ctx.Pagination{page: 2, entries: [...]}
  ```
  """
  @spec next_page(Pagination.t()) :: Pagination.t()
  def next_page(%Pagination{page: page} = paginate), do: to_page(paginate, page + 1)

  @doc """
  Moves to the previous page in paginated results.

  Safely moves back to the previous page if available. If already on the first
  page, returns the current pagination state with its entries refreshed.

  ## Parameters

  - `paginate` (Aurora.Ctx.Pagination.t()) - Current pagination state

  ## Returns

  `Aurora.Ctx.Pagination.t()` - Pagination struct for the previous page or
  current page refreshed if already at the beginning

  ## Examples

  ```elixir
  page3 = Core.list_paginated(Repo, Product, paginate: %{page: 3, per_page: 20})
  page2 = Core.previous_page(page3)
  #=> %Aurora.Ctx.Pagination{page: 2, entries: [...]}
  ```
  """
  @spec previous_page(Pagination.t()) :: Pagination.t()
  def previous_page(%Pagination{page: page} = paginate), do: to_page(paginate, page - 1)

  @doc """
  Counts total records matching the specified query conditions.

  Efficiently counts records by excluding unnecessary query clauses like select,
  limit, offset, and order_by that don't affect the count result.

  ## Parameters

  - `repo_module` (module()) - Ecto.Repo module to use for database operations
  - `schema_module` (module()) - Schema module to query
  - `opts` (keyword()) - Query filtering options supported by
    `Aurora.Ctx.QueryBuilder`

  ## Returns

  `non_neg_integer()` - Total count of records matching the query conditions

  ## Examples

  ```elixir
  # Count all products
  Core.count(Repo, Product)
  #=> 1250

  # Count with filtering
  Core.count(Repo, Product, where: [status: :active, category_id: 1])
  #=> 45
  ```
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
  Creates a new record using the default changeset function.

  Convenience function that calls `create/4` with the default `:changeset`
  function and provided attributes.

  ## Parameters

  - `repo_module` (module()) - Ecto.Repo module to use for database operations
  - `schema_module_or_changeset` (module() | Ecto.Changeset.t()) - Schema module
    or existing changeset to create from
  - `attrs` (map()) - Attributes for the new record

  ## Returns

  - `{:ok, Ecto.Schema.t()}` - Successfully created record
  - `{:error, Ecto.Changeset.t()}` - Validation or constraint errors

  ## Examples

  ```elixir
  # Create with schema module
  Core.create(Repo, Product, %{name: "Widget", price: 99.99})
  #=> {:ok, %Product{name: "Widget", price: 99.99}}

  # Create with existing changeset
  changeset = Product.changeset(%Product{}, %{name: "Gadget"})
  Core.create(Repo, changeset, %{price: 49.99})
  #=> {:ok, %Product{name: "Gadget", price: 49.99}}
  ```
  """
  @spec create(module(), module() | Ecto.Changeset.t(), map()) ::
          {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def create(repo_module, schema_module_or_changeset, %{} = attrs),
    do: create(repo_module, schema_module_or_changeset, :changeset, attrs)

  @doc """
  Creates a new record with a custom changeset function.

  Provides flexibility to use custom changeset functions for specialized
  validation or transformation logic during record creation.

  ## Parameters

  - `repo_module` (module()) - Ecto.Repo module to use for database operations
  - `schema_module` (module() | Ecto.Changeset.t()) - Schema module or existing
    changeset to create from
  - `changeset_function` (atom() | function()) - Changeset function to apply:
    - `atom()` - Function name assumed to exist in the schema module
    - `function()` - Direct function reference with arity 2
  - `attrs` (map()) - Attributes for the new record

  ## Returns

  - `{:ok, Ecto.Schema.t()}` - Successfully created record
  - `{:error, Ecto.Changeset.t()}` - Validation or constraint errors

  ## Examples

  ```elixir
  # Using custom changeset function by name
  Core.create(Repo, Product, :registration_changeset, %{
    name: "Widget",
    code: "WDG001"
  })
  #=> {:ok, %Product{name: "Widget", code: "WDG001"}}

  # Using function reference
  custom_fn = &Product.custom_changeset/2
  Core.create(Repo, Product, custom_fn, %{name: "Gadget"})
  #=> {:ok, %Product{name: "Gadget"}}
  ```
  """
  @spec create(module(), module() | Ecto.Changeset.t(), atom() | function(), map()) ::
          {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}

  def create(
        repo_module,
        schema_module_or_changeset,
        changeset_function \\ :changeset,
        attrs \\ %{}
      )

  def create(repo_module, changeset_or_entity, changeset_function, attrs)
      when is_function(changeset_function, 2) do
    changeset_or_entity
    |> changeset_function.(attrs)
    |> repo_module.insert()
  end

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
  Creates a new record using the default changeset function, raising on errors.

  Convenience function that calls `create!/4` with the default `:changeset`
  function and provided attributes.

  ## Parameters

  - `repo_module` (module()) - Ecto.Repo module to use for database operations
  - `schema_module_or_changeset` (module() | Ecto.Changeset.t()) - Schema module
    or existing changeset to create from
  - `attrs` (map()) - Attributes for the new record

  ## Returns

  `Ecto.Schema.t()` - Successfully created record

  ## Raises

  - `Ecto.InvalidChangesetError` - Invalid changeset data
  - `Ecto.ConstraintError` - Database constraint violations

  ## Examples

  ```elixir
  product = Core.create!(Repo, Product, %{name: "Widget", price: 99.99})
  #=> %Product{name: "Widget", price: 99.99}
  ```
  """
  @spec create!(module(), module() | Ecto.Changeset.t(), map()) :: Ecto.Schema.t()
  def create!(repo_module, schema_module_or_changeset, %{} = attrs),
    do: create!(repo_module, schema_module_or_changeset, :changeset, attrs)

  @doc """
  Creates a new record with a custom changeset function, raising on errors.

  ## Parameters

  - `repo_module` (module()) - Ecto.Repo module to use for database operations
  - `schema_module_or_changeset` (module() | Ecto.Changeset.t()) - Schema module
    or existing changeset to create from
  - `changeset_function` (atom() | function()) - Changeset function to apply:
    - `atom()` - Function name assumed to exist in the schema module
    - `function()` - Direct function reference with arity 2
  - `attrs` (map()) - Attributes for the new record

  ## Returns

  `Ecto.Schema.t()` - Successfully created record

  ## Raises

  - `Ecto.InvalidChangesetError` - Invalid changeset data
  - `Ecto.ConstraintError` - Database constraint violations

  ## Examples

  ```elixir
  product = Core.create!(Repo, Product, :registration_changeset, %{
    name: "Widget",
    code: "WDG001"
  })
  #=> %Product{name: "Widget", code: "WDG001"}
  ```
  """
  @spec create!(module(), module() | Ecto.Changeset.t(), atom() | function(), map()) ::
          Ecto.Schema.t()
  def create!(
        repo_module,
        schema_module_or_changeset,
        changeset_function \\ :changeset,
        attrs \\ %{}
      )

  def create!(repo_module, schema_module, changeset_function, attrs)
      when is_function(changeset_function, 2) do
    schema_module.__struct__()
    |> changeset_function.(attrs)
    |> repo_module.insert!()
  end

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
  Gets a single record by its primary key.

  Supports additional query options for preloading associations and other
  query modifications processed by `Aurora.Ctx.QueryBuilder`.

  ## Parameters

  - `repo_module` (module()) - Ecto.Repo module to use for database operations
  - `schema_module` (module()) - Schema module to query
  - `id` (term()) - Primary key value to look up
  - `opts` (keyword()) - Query options:
    - `preload: atom() | list()` - Associations to preload
    - Plus other options supported by `Aurora.Ctx.QueryBuilder`

  ## Returns

  - `Ecto.Schema.t()` - Found record
  - `nil` - No record found with the given primary key

  ## Examples

  ```elixir
  # Get by ID
  Core.get(Repo, Product, 123)
  #=> %Product{id: 123, name: "Widget"}

  # Get with preloaded associations
  Core.get(Repo, Product, 123, preload: [:category, :reviews])
  #=> %Product{id: 123, category: %Category{}, reviews: [%Review{}]}
  ```
  """
  @spec get(module(), module(), term(), keyword()) :: Ecto.Schema.t() | nil
  def get(repo_module, schema_module, id, opts \\ []) do
    schema_module
    |> from()
    |> QueryBuilder.options(opts)
    |> repo_module.get(id)
  end

  @doc """
  Gets a single record by its primary key, raising if not found.

  ## Parameters

  - `repo_module` (module()) - Ecto.Repo module to use for database operations
  - `schema_module` (module()) - Schema module to query
  - `id` (term()) - Primary key value to look up
  - `opts` (keyword()) - Query options supported by `Aurora.Ctx.QueryBuilder`

  ## Returns

  `Ecto.Schema.t()` - Found record

  ## Raises

  `Ecto.NoResultsError` - No record found with the given primary key

  ## Examples

  ```elixir
  product = Core.get!(Repo, Product, 123)
  #=> %Product{id: 123, name: "Widget"}

  Core.get!(Repo, Product, 999)
  #=> ** (Ecto.NoResultsError)
  ```
  """
  @spec get!(module(), module(), term(), keyword()) :: Ecto.Schema.t()
  def get!(repo_module, schema_module, id, opts \\ []) do
    schema_module
    |> from()
    |> QueryBuilder.options(opts)
    |> repo_module.get!(id)
  end

  @doc """
  Gets a single record by filtering clauses.

  Finds the first record matching the given clauses. If multiple records match,
  only the first one is returned. Use `get_by!/4` for strict single-result
  enforcement.

  ## Parameters

  - `repo_module` (module()) - Ecto.Repo module to use for database operations
  - `schema_module` (module()) - Schema module to query
  - `clauses` (keyword()) - Filter conditions as key-value pairs
  - `opts` (keyword()) - Query options supported by `Aurora.Ctx.QueryBuilder`

  ## Returns

  - `Ecto.Schema.t()` - First matching record
  - `nil` - No record matches the given clauses

  ## Examples

  ```elixir
  # Get by single field
  Core.get_by(Repo, Product, name: "Widget")
  #=> %Product{name: "Widget"}

  # Get by multiple fields
  Core.get_by(Repo, Product, [name: "Widget", status: :active])
  #=> %Product{name: "Widget", status: :active}

  # With preloading
  Core.get_by(Repo, Product, [code: "WDG001"], preload: [:category])
  #=> %Product{code: "WDG001", category: %Category{}}
  ```
  """
  @spec get_by(module(), module(), keyword(), keyword()) :: Ecto.Schema.t() | nil
  def get_by(repo_module, schema_module, clauses, opts \\ []) do
    schema_module
    |> from()
    |> QueryBuilder.options(opts)
    |> repo_module.get_by(clauses)
  end

  @doc """
  Gets a single record by filtering clauses, raising if not found or multiple found.

  ## Parameters

  - `repo_module` (module()) - Ecto.Repo module to use for database operations
  - `schema_module` (module()) - Schema module to query
  - `clauses` (keyword()) - Filter conditions as key-value pairs
  - `opts` (keyword()) - Query options supported by `Aurora.Ctx.QueryBuilder`

  ## Returns

  `Ecto.Schema.t()` - The unique matching record

  ## Raises

  - `Ecto.NoResultsError` - No record matches the given clauses
  - `Ecto.MultipleResultsError` - Multiple records match the given clauses

  ## Examples

  ```elixir
  product = Core.get_by!(Repo, Product, code: "WDG001")
  #=> %Product{code: "WDG001"}

  Core.get_by!(Repo, Product, name: "NonExistent")
  #=> ** (Ecto.NoResultsError)
  ```
  """
  @spec get_by!(module(), module(), keyword(), keyword()) :: Ecto.Schema.t()
  def get_by!(repo_module, schema_module, clauses, opts \\ []) do
    schema_module
    |> from()
    |> QueryBuilder.options(opts)
    |> repo_module.get_by!(clauses)
  end

  @doc """
  Deletes the given entity from the database.

  ## Parameters

  - `repo_module` (module()) - Ecto.Repo module to use for database operations
  - `entity` (Ecto.Schema.t()) - Entity struct to delete

  ## Returns

  - `{:ok, Ecto.Schema.t()}` - Successfully deleted entity
  - `{:error, Ecto.Changeset.t()}` - Delete operation failed

  ## Examples

  ```elixir
  product = Core.get!(Repo, Product, 123)
  {:ok, deleted_product} = Core.delete(Repo, product)
  #=> {:ok, %Product{id: 123, ...}}
  ```
  """
  @spec delete(module(), Ecto.Schema.t()) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def delete(repo_module, entity), do: repo_module.delete(entity)

  @doc """
  Deletes the given entity from the database, raising on errors.

  ## Parameters

  - `repo_module` (module()) - Ecto.Repo module to use for database operations
  - `entity` (Ecto.Schema.t()) - Entity struct to delete

  ## Returns

  `Ecto.Schema.t()` - Successfully deleted entity

  ## Raises

  `Ecto.StaleEntryError` - Entity has been modified or deleted by another process

  ## Examples

  ```elixir
  product = Core.get!(Repo, Product, 123)
  deleted_product = Core.delete!(Repo, product)
  #=> %Product{id: 123, ...}
  ```
  """
  @spec delete!(module(), Ecto.Schema.t()) :: Ecto.Schema.t()
  def delete!(repo_module, entity), do: repo_module.delete!(entity)

  @doc """
  Updates an entity with given attributes using the default changeset function.

  Convenience function that calls `update/4` with the default `:changeset`
  function and provided attributes.

  ## Parameters

  - `repo_module` (module()) - Ecto.Repo module to use for database operations
  - `entity_or_changeset` (Ecto.Schema.t() | Ecto.Changeset.t()) - Existing
    record to update or changeset to apply
  - `attrs` (map()) - Update attributes

  ## Returns

  - `{:ok, Ecto.Schema.t()}` - Successfully updated record
  - `{:error, Ecto.Changeset.t()}` - Validation or constraint errors

  ## Examples

  ```elixir
  product = Core.get!(Repo, Product, 123)
  {:ok, updated} = Core.update(Repo, product, %{name: "New Name", price: 89.99})
  #=> {:ok, %Product{name: "New Name", price: 89.99}}
  ```
  """
  @spec update(module(), Ecto.Schema.t() | Ecto.Changeset.t(), map()) ::
          {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}

  def update(repo_module, entity_or_changeset, %{} = attrs),
    do: update(repo_module, entity_or_changeset, :changeset, attrs)

  @doc """
  Updates an entity using a specific changeset function.

  Provides flexibility to use custom changeset functions for specialized
  validation or transformation logic during record updates.

  ## Parameters

  - `repo_module` (module()) - Ecto.Repo module to use for database operations
  - `entity_or_changeset` (Ecto.Schema.t() | Ecto.Changeset.t()) - Existing
    record to update or changeset to apply
  - `changeset_function` (atom() | function()) - Changeset function to apply:
    - `atom()` - Function name assumed to exist in the schema module
    - `function()` - Direct function reference with arity 2
  - `attrs` (map()) - Update attributes

  ## Returns

  - `{:ok, Ecto.Schema.t()}` - Successfully updated record
  - `{:error, Ecto.Changeset.t()}` - Validation or constraint errors

  ## Examples

  ```elixir
  product = Core.get!(Repo, Product, 123)
  {:ok, updated} = Core.update(Repo, product, :update_changeset, %{
    price: 79.99,
    updated_reason: "Price adjustment"
  })
  #=> {:ok, %Product{price: 79.99, updated_reason: "Price adjustment"}}
  ```
  """
  @spec update(module(), Ecto.Schema.t() | Ecto.Changeset.t(), atom() | function(), map()) ::
          {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def update(repo_module, entity_or_changeset, changeset_function \\ :changeset, attrs \\ %{})

  def update(repo_module, changeset_or_entity, changeset_function, attrs)
      when is_function(changeset_function, 2) do
    changeset_or_entity
    |> changeset_function.(attrs)
    |> repo_module.update()
  end

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
  Creates a changeset for the given entity using the default changeset function.

  Convenience function that calls `change/3` with the default `:changeset`
  function and provided attributes.

  ## Parameters

  - `entity_or_changeset` (Ecto.Schema.t() | Ecto.Changeset.t()) - Existing
    record or changeset to create changeset from
  - `attrs` (map()) - Changeset attributes

  ## Returns

  `Ecto.Changeset.t()` - Changeset with applied attributes and validations

  ## Examples

  ```elixir
  product = %Product{name: "Widget"}
  changeset = Core.change(product, %{name: "New Widget", price: 99.99})
  #=> #Ecto.Changeset<changes: %{name: "New Widget", price: 99.99}>
  ```
  """
  @spec change(Ecto.Schema.t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def change(entity_or_changeset, %{} = attrs), do: change(entity_or_changeset, :changeset, attrs)

  @doc """
  Creates a changeset for the given entity using a specific changeset function.

  Provides flexibility to use custom changeset functions for specialized
  validation or transformation logic when building changesets.

  ## Parameters

  - `entity_or_changeset` (Ecto.Schema.t() | Ecto.Changeset.t()) - Existing
    record or changeset to create changeset from
  - `changeset_function` (atom() | function()) - Changeset function to apply:
    - `atom()` - Function name assumed to exist in the schema module
    - `function()` - Direct function reference with arity 2
  - `attrs` (map()) - Changeset attributes

  ## Returns

  `Ecto.Changeset.t()` - Changeset with applied attributes and validations

  ## Examples

  ```elixir
  product = %Product{name: "Widget"}
  changeset = Core.change(product, :update_changeset, %{price: 89.99})
  #=> #Ecto.Changeset<changes: %{price: 89.99}>

  # Using function reference
  custom_fn = &Product.custom_changeset/2
  changeset = Core.change(product, custom_fn, %{status: :active})
  #=> #Ecto.Changeset<changes: %{status: :active}>
  ```
  """
  @spec change(Ecto.Schema.t() | Ecto.Changeset.t(), atom() | function(), map()) ::
          Ecto.Changeset.t()
  def change(entity_or_changeset, changeset_function \\ :changeset, attrs \\ %{})

  def change(changeset_or_entity, changeset_function, attrs)
      when is_function(changeset_function, 2) do
    changeset_function.(changeset_or_entity, attrs)
  end

  def change(%Ecto.Changeset{} = changeset, changeset_function, attrs) do
    apply(changeset.data.__struct__, changeset_function, [changeset, attrs])
  end

  def change(entity, changeset_function, attrs) do
    apply(entity.__struct__, changeset_function, [entity, attrs])
  end

  @doc """
  Initializes a new schema struct with optional attributes.

  Convenience function that calls `new/4` with empty options when provided
  with a map of attributes, or calls `new/4` with empty attributes when
  provided with a keyword list of options.

  ## Parameters

  - `repo_module` (module()) - Ecto.Repo module to use for potential preloading
  - `schema_module` (module()) - Schema module to initialize
  - `attrs_or_opts` - Either:
    - `map()` - Initial attributes (will use empty options)
    - `keyword()` - Options including preload specifications (will use empty
      attributes)

  ## Returns

  `Ecto.Schema.t()` - Initialized schema struct

  ## Examples

  ```elixir
  # Initialize with attributes
  product = Core.new(Repo, Product, %{name: "Widget", price: 99.99})
  #=> %Product{name: "Widget", price: 99.99}

  # Initialize with preload options
  product = Core.new(Repo, Product, preload: [:category])
  #=> %Product{category: %Category{}}
  ```
  """
  @spec new(module(), module(), map() | keyword()) :: Ecto.Schema.t()
  def new(repo_module, schema_module, %{} = attrs), do: new(repo_module, schema_module, attrs, [])

  def new(repo_module, schema_module, opts) when is_list(opts),
    do: new(repo_module, schema_module, %{}, opts)

  @doc """
  Initializes a new schema struct with attributes and optional preloads.

  Creates a new struct instance and optionally preloads specified associations.
  Useful for preparing new records with related data for forms or other
  operations.

  ## Parameters

  - `repo_module` (module()) - Ecto.Repo module to use for preloading operations
  - `schema_module` (module()) - Schema module to initialize
  - `attrs` (map()) - Initial attributes to set on the struct
  - `opts` (keyword()) - Options:
    - `preload: atom() | list()` - Associations to preload

  ## Returns

  `Ecto.Schema.t()` - Initialized schema struct with preloaded associations

  ## Examples

  ```elixir
  # Basic initialization
  product = Core.new(Repo, Product, %{name: "Widget"}, [])
  #=> %Product{name: "Widget"}

  # With preloaded associations
  product = Core.new(Repo, Product, %{name: "Widget"}, preload: [:category])
  #=> %Product{name: "Widget", category: %Category{}}
  ```
  """
  @spec new(module(), module(), map(), keyword()) :: Ecto.Schema.t()
  def new(repo_module, schema_module, attrs \\ %{}, opts \\ []) do
    attrs
    |> schema_module.__struct__()
    |> repo_preload(repo_module, opts[:preload])
  end

  @doc """
  Excludes specific query clauses from an Ecto query.

  Removes unwanted clauses from a query, which is useful for operations like
  counting where certain clauses (select, limit, offset, order_by) are not
  needed and may interfere with the operation.

  ## Parameters

  - `query` (Ecto.Query.t()) - Query to modify by excluding clauses
  - `clauses` (atom() | list(atom())) - Clause(s) to exclude. Available clauses:
    - `:where` - WHERE conditions
    - `:select` - SELECT clauses
    - `:order_by` - ORDER BY clauses
    - `:group_by` - GROUP BY clauses
    - `:having` - HAVING conditions
    - `:limit` - LIMIT clause
    - `:offset` - OFFSET clause
    - `:preload` - Preload associations
    - `:lock` - Lock clauses

  ## Returns

  `Ecto.Query.t()` - Modified query with specified clauses excluded

  ## Examples

  ```elixir
  query = from(p in Product, where: p.status == :active, order_by: p.name)

  # Exclude single clause
  exclude_clauses(query, :order_by)
  #=> query without ORDER BY clause

  # Exclude multiple clauses
  exclude_clauses(query, [:select, :order_by, :limit])
  #=> query without SELECT, ORDER BY, or LIMIT clauses
  ```
  """
  @spec exclude_clauses(Ecto.Query.t(), atom() | list(atom())) :: Ecto.Query.t()
  def exclude_clauses(query, clauses) when is_list(clauses) do
    Enum.reduce(clauses, query, &Ecto.Query.exclude(&2, &1))
  end

  def exclude_clauses(query, clause) when is_atom(clause), do: Ecto.Query.exclude(query, clause)

  ## PRIVATE

  # Preloads associations on an entity if preload options are provided
  @spec repo_preload(Ecto.Schema.t(), module(), term()) :: Ecto.Schema.t()
  defp repo_preload(entity, _repo_module, nil), do: entity
  defp repo_preload(entity, repo_module, preload), do: repo_module.preload(entity, preload)
end
