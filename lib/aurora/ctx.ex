defmodule Aurora.Ctx do
  @moduledoc """
  A module for automatically generating CRUD operations for Ecto schemas.

  This module provides macros to generate standard database operation functions
  based on Ecto schemas. It simplifies the creation of context modules by
  automatically implementing common CRUD operations.

  ## Usage

      defmodule MyApp.Accounts do
        use Aurora.Ctx

        ctx_register_schema(User)
        # or with options
        ctx_register_schema(User, CustomRepo,
          update_changeset: :custom_changeset,
          create_changeset: :create_changeset
        )
      end

  For detailed examples of using the generated functions, see [Examples Guide](examples.html).

  ## Generated Functions

  For a schema with source name "users" and module name "user", the following functions are generated:

  ### List Functions
  - `list_users/0` - List all records
  - `list_users/1` - List all records with options
  - `list_users_paginated/0` - List records with pagination
  - `list_users_paginated/1` - List records with pagination and options
  - `count_users/0` - Count total records
  - `count_users/1` - Count records with options

  ### Pagination Functions
  - `to_users_page/2` - Navigate to a specific page
  - `next_users_page/1` - Navigate to the next page
  - `previous_users_page/1` - Navigate to the previous page

  ### Create Functions
  - `create_user/0` - Create a record with empty attributes
  - `create_user/1` - Create a record with given attributes
  - `create_user!/0` - Create a record with empty attributes (raises on error)
  - `create_user!/1` - Create a record with given attributes (raises on error)

  ### Get Functions
  - `get_user/1` - Get a record by ID
  - `get_user/2` - Get a record by ID with options
  - `get_user!/1` - Get a record by ID (raises if not found)
  - `get_user!/2` - Get a record by ID with options (raises if not found)

  ### Delete Functions
  - `delete_user/1` - Delete a record
  - `delete_user!/1` - Delete a record (raises on error)

  ### Change Functions
  - `change_user/1` - Create a changeset from a record
  - `change_user/2` - Create a changeset from a record with attributes

  ### Update Functions
  - `update_user/1` - Update a record
  - `update_user/2` - Update a record with attributes

  ### New Functions
  - `new_user/0` - Initialize a new struct
  - `new_user/1` - Initialize a new struct with attributes
  - `new_user/2` - Initialize a new struct with attributes and options
  """

  alias Aurora.Ctx

  require Logger

  @doc false
  defmacro __using__(_opts) do
    quote do
      import Aurora.Ctx,
        only: [ctx_register_schema: 1, ctx_register_schema: 2, ctx_register_schema: 3]

      Module.register_attribute(__MODULE__, :_ctx_crud_schema, accumulate: true)
      @before_compile Ctx
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    functions =
      env.module
      |> Module.get_attribute(:_ctx_crud_schema, [])
      |> Enum.map(&register_schema(env.module, &1))

    quote do
      unquote(functions)
    end
  end

  @doc """
  Registers a schema for CRUD function generation.

  ## Parameters
    * `schema_module` (module()) - The Ecto schema module to generate functions for
    * `repo` (module() | nil) - (Optional) The Ecto.Repo to use for database operations. Can be set globally with `@ctx_repo_module`
    * `opts` (keyword()) - (Optional) Configuration options:
      * `:changeset` (atom()) - A specific function to use for change function changesets (default: `:changeset`)
      * `:create_changeset` (atom()) - A specific function to use for creation changesets (defaults to the value of option `:changeset` or the function `:changeset`)
      * `:infix` (binary) - The fixed part to use when constructing the functions' names.
          By default, is the lowercase of the module name (the last part of the full module name).
      * `:plural_infix` (binary) - The fixed part to use when constructing the functions' names for plural functions.
          By default, uses the table name defined in the schema module.
      * `:update_changeset` (atom()) - The function to use for changesets (defaults to the value of option `:changeset` or the function `:changeset`)

  ## Repository Configuration
  The Ecto.Repo can be configured in two ways:
    1. Passing it as the second argument to `ctx_register_schema/3`
    2. Setting the `@ctx_repo_module` module attribute in your context

  If neither is specified, it will attempt to use `YourApp.Repo` based on your
  context module's namespace.

  ## Function Names

  Given a User schema with table "users":

      # Default naming (no options)
      get_user/1          # Singular functions use module name
      list_users/0        # Plural functions use table name

      # With infix: "customer"
      get_customer/1      # Singular functions use custom infix
      list_users/0        # Plural functions still use table name

      # With plural_infix: "customers"
      get_user/1          # Singular functions use module name
      list_customers/0    # Plural functions use custom plural infix

      # With both infix: "customer" and plural_infix: "customers"
      get_customer/1      # Singular functions use custom infix
      list_customers/0    # Plural functions use custom plural infix

  ## Examples

      # Using explicit repo
      ctx_register_schema(User, MyApp.Repo)

      # Using module attribute
      @ctx_repo_module MyApp.Repo
      ctx_register_schema(User)

      # Generating custom function names
      ctx_register_schema(User, MyApp.Repo,
        infix: "customer",
        plural_infix: "customers"
      )
  """
  @spec ctx_register_schema(module, module | keyword) :: Macro.t()
  defmacro ctx_register_schema(schema_module, opts) when is_list(opts) do
    quote do
      ctx_register_schema(unquote(schema_module), nil, unquote(opts))
    end
  end

  @spec ctx_register_schema(module, module | nil, keyword) :: Macro.t()
  defmacro ctx_register_schema(schema_module, repo \\ nil, opts \\ []) do
    quote do
      Module.put_attribute(__MODULE__, :_ctx_crud_schema, %{
        schema_module: unquote(schema_module),
        repo: unquote(repo),
        opts: unquote(opts)
      })
    end
  end

  @doc """
  Lists all implementable CRUD functions for a given schema.

  This function is used internally to determine which functions should be generated
  for a given schema. It returns a list of maps containing function definitions.

  ## Parameters
    * `schema_module` - The Ecto schema module to analyze
    * `opts` - Options that affect function generation:
      * `:infix` - Custom infix for singular function names
      * `:plural_infix` - Custom infix for plural function names

  ## Returns
    * List of maps containing:
      * `:type` - The function type:
        * `:list` - Functions that return collections of records
        * `:list_paginated` - Functions that return paginated results
        * `:count` - Functions that count records
        * `:create` - Functions that create new records
        * `:get` - Functions that fetch single records
        * `:delete` - Functions that remove records
        * `:change` - Functions that create changesets
        * `:update` - Functions that modify records
        * `:new` - Functions that initialize structs
        * `:to_page`, `:next_page`, `:previous_page` - Pagination navigation
      * `:name` - The generated function name as an atom
      * `:arity` - The function arity (number of arguments)
  """
  @spec implementable_functions(module(), keyword) :: list()
  def implementable_functions(schema_module, opts \\ []) do
    plural_infix =
      opts
      |> get_option(:plural_infix, schema_module.__schema__(:source))
      |> Macro.underscore()

    infix =
      opts
      |> get_option(:infix, schema_module |> Module.split() |> List.last())
      |> Macro.underscore()

    [
      %{type: :list, name: "list_#{plural_infix}", arity: 0},
      %{type: :list, name: "list_#{plural_infix}", arity: 1},
      %{type: :list_paginated, name: "list_#{plural_infix}_paginated", arity: 0},
      %{type: :list_paginated, name: "list_#{plural_infix}_paginated", arity: 1},
      %{type: :count, name: "count_#{plural_infix}", arity: 0},
      %{type: :count, name: "count_#{plural_infix}", arity: 1},
      %{type: :to_page, name: "to_#{plural_infix}_page", arity: 2},
      %{type: :next_page, name: "next_#{plural_infix}_page", arity: 1},
      %{type: :previous_page, name: "previous_#{plural_infix}_page", arity: 1},
      %{type: :create, name: "create_#{infix}", arity: 0},
      %{type: :create, name: "create_#{infix}", arity: 1},
      %{type: :create, name: "create_#{infix}!", arity: 0},
      %{type: :create, name: "create_#{infix}!", arity: 1},
      %{type: :get, name: "get_#{infix}", arity: 1},
      %{type: :get, name: "get_#{infix}", arity: 2},
      %{type: :get, name: "get_#{infix}!", arity: 1},
      %{type: :get, name: "get_#{infix}!", arity: 2},
      %{type: :get_by, name: "get_#{infix}_by", arity: 1},
      %{type: :get_by, name: "get_#{infix}_by", arity: 2},
      %{type: :get_by, name: "get_#{infix}_by!", arity: 1},
      %{type: :get_by, name: "get_#{infix}_by!", arity: 2},
      %{type: :delete, name: "delete_#{infix}", arity: 1},
      %{type: :delete, name: "delete_#{infix}!", arity: 1},
      %{type: :change, name: "change_#{infix}", arity: 1},
      %{type: :change, name: "change_#{infix}", arity: 2},
      %{type: :update, name: "update_#{infix}", arity: 1},
      %{type: :update, name: "update_#{infix}", arity: 2},
      %{type: :new, name: "new_#{infix}", arity: 0},
      %{type: :new, name: "new_#{infix}", arity: 1},
      %{type: :new, name: "new_#{infix}", arity: 2}
    ]
  end

  ## PRIVATE

  @spec register_schema(module, map) :: Macro.t()
  defp register_schema(
         context_module,
         %{schema_module: schema_module, repo: repo, opts: opts}
       ) do
    repo_module =
      get_repo_module(context_module, repo)

    changeset = Keyword.get(opts, :changeset, :changeset)

    create_changeset = Keyword.get(opts, :create_changeset, changeset)

    update_changeset = Keyword.get(opts, :update_changeset, changeset)

    implemented_functions =
      schema_module
      |> implementable_functions(opts)
      |> Enum.map(
        &Map.merge(&1, %{
          repo_module: repo_module,
          schema_module: schema_module,
          changeset: changeset,
          create_changeset: create_changeset,
          update_changeset: update_changeset,
          name: String.to_atom(&1.name)
        })
      )

    imports =
      quote do
        alias Aurora.Ctx
      end

    functions =
      implemented_functions
      |> Enum.reject(&Module.defines?(context_module, {&1.name, &1.arity}, :def))
      |> Enum.map(&generate_function/1)

    quote do
      unquote(imports)
      unquote(functions)
    end
  end

  # Function templates
  # Functions (using schema 'Product' as example):
  # list_products()
  # list_products(opts)
  # list_products_paginated()
  # list_products_paginated(opts)
  # count_products()
  # count_products(opts)
  # get_product_by(clauses)
  # get_product_by(clauses, opts)
  # get_product_by!(clauses)
  # get_product_by!(clauses, opts)
  # new_product()
  # new_product(attrs)
  # new_product(opts)
  # new_product(attrs, opts)
  @spec generate_function(map) :: Macro.t()
  defp generate_function(%{type: type, arity: arity} = function)
       when type in [:list, :list_paginated, :count, :new, :get_by] do
    core_function = core_function(function, function.type)

    args =
      case arity do
        1 -> [quote(do: arg1)]
        2 -> [quote(do: arg1), quote(do: arg2)]
        _ -> []
      end

    quote do
      @doc false
      def unquote(function.name)(unquote_splicing(args)) do
        apply(Ctx.Core, unquote(core_function), [
          unquote(function.repo_module),
          unquote(function.schema_module),
          unquote_splicing(args)
        ])
      end
    end
  end

  # Functions (using schema 'Product' as example):
  # create_product()
  # create_product(attrs)
  # create_product!(attrs)
  # create_product!()
  defp generate_function(%{type: :create, arity: arity} = function) do
    core_function = core_function(function, "create")

    arg = if arity == 1, do: [quote(do: attrs)], else: []
    attrs = if arity == 1, do: [quote(do: attrs)], else: [nil]

    quote do
      @doc false
      def unquote(function.name)(unquote_splicing(arg)) do
        apply(Ctx.Core, unquote(core_function), [
          unquote(function.repo_module),
          unquote(function.schema_module),
          unquote(function.create_changeset),
          unquote_splicing(attrs)
        ])
      end
    end
  end

  # Functions (using schema 'Product' as example):
  # get_product(id)
  # get_product(id, opts)
  # get_product!(id)
  # get_product!(id, opts)
  defp generate_function(%{type: :get, arity: arity} = function) do
    core_function = core_function(function, "get")

    arg = if arity == 2, do: [quote(do: id), quote(do: opts)], else: [quote(do: id)]
    opts = if arity == 2, do: [quote(do: opts)], else: [[]]

    quote do
      @doc false
      def unquote(function.name)(unquote_splicing(arg)) do
        apply(Ctx.Core, unquote(core_function), [
          unquote(function.repo_module),
          unquote(function.schema_module),
          id,
          unquote_splicing(opts)
        ])
      end
    end
  end

  # Functions (using schema 'Product' as example):
  # delete_product(entity)
  # delete_product!(entity)
  defp generate_function(%{type: :delete} = function) do
    core_function = core_function(function, "delete")

    quote do
      @doc false
      def unquote(function.name)(entity) do
        apply(Ctx.Core, unquote(core_function), [unquote(function.repo_module), entity])
      end
    end
  end

  # Functions (using schema 'Product' as example):
  # change_product(entity)
  # change_product(entity, attrs)
  defp generate_function(%{type: :change, arity: arity} = function) do
    args = if arity > 1, do: [quote(do: entity), quote(do: attrs)], else: [quote(do: entity)]

    core_function_call =
      if arity > 1 do
        quote do
          @doc false
          def unquote(function.name)(unquote_splicing(args)) do
            Ctx.Core.change(entity, unquote(function.changeset), attrs)
          end
        end
      else
        quote do
          @doc false
          def unquote(function.name)(unquote_splicing(args)) do
            Ctx.Core.change(entity, unquote(function.changeset))
          end
        end
      end

    quote do
      unquote(core_function_call)
    end
  end

  # Functions (using schema 'Product' as example):
  # update_product(entity)
  # update_product(entity, attrs)
  defp generate_function(%{type: :update, arity: arity} = function) do
    args = if arity > 1, do: [quote(do: entity), quote(do: attrs)], else: [quote(do: entity)]
    attrs = if arity > 1, do: [quote(do: attrs)], else: []

    quote do
      @doc false
      def unquote(function.name)(unquote_splicing(args)) do
        Ctx.Core.update(
          unquote(function.repo_module),
          entity,
          unquote(function.update_changeset),
          unquote_splicing(attrs)
        )
      end
    end
  end

  defp generate_function(%{type: :to_page} = function) do
    quote do
      @doc false
      def unquote(function.name)(pagination, page) do
        Ctx.Core.to_page(pagination, page)
      end
    end
  end

  defp generate_function(%{type: type} = function) when type in [:next_page, :previous_page] do
    quote do
      @doc false
      def unquote(function.name)(pagination) do
        apply(Ctx.Core, unquote(function.type), [pagination])
      end
    end
  end

  # Functions (using schema 'Product' as example):

  defp generate_function(_func), do: quote(do: :ok)

  @spec core_function(map(), binary() | atom()) :: atom()
  defp core_function(function, core_function_name) do
    function.name
    |> to_string()
    |> String.ends_with?("!")
    |> maybe_add_bang(core_function_name)
    |> String.to_atom()
  end

  @spec maybe_add_bang(boolean(), binary()) :: binary()
  defp maybe_add_bang(true, repo_function_name), do: "#{repo_function_name}!"
  defp maybe_add_bang(_, repo_function_name), do: "#{repo_function_name}"

  @spec get_repo_module(module, module | nil) :: module
  defp get_repo_module(context_module, nil) do
    case Module.get_attribute(context_module, :ctx_repo_module) do
      nil ->
        context_module
        |> Module.split()
        |> List.first()
        |> then(&Module.concat(&1, Repo))
        |> tap(&Logger.warning(~s"No Ecto repo was explicitly specified.
          You can either pass the repo module as the second argument,
          or configure a global repo module using @ctx_repo_module.
          In this case, the module #{&1} was chosen based on typical default conventions."))

      repo ->
        repo
    end
  end

  defp get_repo_module(_context_module, repo), do: repo

  @spec get_option(keyword, atom, binary) :: binary
  defp get_option(opts, tag, default) do
    case opts[tag] do
      nil -> default
      option -> option
    end
  end
end
