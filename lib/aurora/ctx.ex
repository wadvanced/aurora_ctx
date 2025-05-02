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
          changeset_function: :custom_changeset,
          create_changeset_function: :create_changeset
        )
      end

  ## Generated Functions

  For a schema with source name "users" and module name "user", the following functions are generated:

  ### List Functions
  - `list_users/0` - List all records
  - `list_users/1` - List all records with options
  - `list_users_paginated/0` - List records with pagination
  - `list_users_paginated/1` - List records with pagination and options
  - `count_users/0` - Count total records
  - `count_users/1` - Count records with options

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
      * `:changeset_function` (atom()) - The function to use for changesets (default: `:changeset`)
      * `:create_changeset_function` (atom()) - A specific function to use for creation changesets

  ## Repository Configuration
  The Ecto.Repo can be configured in two ways:
    1. Passing it as the second argument to `ctx_register_schema/3`
    2. Setting the `@ctx_repo_module` module attribute in your context

  If neither is specified, it will attempt to use `YourApp.Repo` based on your
  context module's namespace.

  ## Example

      # Using explicit repo
      ctx_register_schema(User, MyApp.Repo)

      # Using module attribute
      @ctx_repo_module MyApp.Repo
      ctx_register_schema(User)

      # With additional options
      ctx_register_schema(User, MyApp.Repo, changeset_function: :custom_changeset)
  """
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

  ## Returns
    * List of maps containing:
      * `:type` - The function type (`:list`, `:create`, etc.)
      * `:name` - The function name
      * `:arity` - The function arity
  """
  @spec implementable_functions(module()) :: list()
  def implementable_functions(schema_module) do
    source = schema_module.__schema__(:source)

    module =
      schema_module
      |> Module.split()
      |> List.last()
      |> Macro.underscore()

    [
      %{type: :list, name: "list_#{source}", arity: 0},
      %{type: :list, name: "list_#{source}", arity: 1},
      %{type: :list_paginated, name: "list_#{source}_paginated", arity: 0},
      %{type: :list_paginated, name: "list_#{source}_paginated", arity: 1},
      %{type: :count, name: "count_#{source}", arity: 0},
      %{type: :count, name: "count_#{source}", arity: 1},
      %{type: :create, name: "create_#{module}", arity: 0},
      %{type: :create, name: "create_#{module}", arity: 1},
      %{type: :create, name: "create_#{module}!", arity: 0},
      %{type: :create, name: "create_#{module}!", arity: 1},
      %{type: :get, name: "get_#{module}", arity: 1},
      %{type: :get, name: "get_#{module}", arity: 2},
      %{type: :get, name: "get_#{module}!", arity: 1},
      %{type: :get, name: "get_#{module}!", arity: 2},
      %{type: :delete, name: "delete_#{module}", arity: 1},
      %{type: :delete, name: "delete_#{module}!", arity: 1},
      %{type: :change, name: "change_#{module}", arity: 1},
      %{type: :change, name: "change_#{module}", arity: 2},
      %{type: :update, name: "update_#{module}", arity: 1},
      %{type: :update, name: "update_#{module}", arity: 2},
      %{type: :new, name: "new_#{module}", arity: 0},
      %{type: :new, name: "new_#{module}", arity: 1},
      %{type: :new, name: "new_#{module}", arity: 2}
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

    create_changeset_function = get_option(opts, :create_changeset_function)
    changeset_function = get_option(opts, :changeset_function)

    implemented_functions =
      schema_module
      |> implementable_functions()
      |> Enum.map(
        &Map.merge(&1, %{
          repo_module: repo_module,
          schema_module: schema_module,
          create_changeset_function: create_changeset_function,
          changeset_function: changeset_function,
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
  # new_product()
  # new_product(attrs)
  # new_product(opts)
  # new_product(attrs, opts)
  @spec generate_function(map) :: Macro.t()
  defp generate_function(%{type: type, arity: arity} = function)
       when type in [:list, :list_paginated, :count, :new] do
    args =
      case arity do
        1 -> [quote(do: arg1)]
        2 -> [quote(do: arg1), quote(do: arg2)]
        _ -> []
      end

    quote do
      @doc false
      def unquote(function.name)(unquote_splicing(args)) do
        apply(Ctx.Core, unquote(function.type), [
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
          unquote(function.create_changeset_function),
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
            Ctx.Core.change(entity, unquote(function.changeset_function), attrs)
          end
        end
      else
        quote do
          @doc false
          def unquote(function.name)(unquote_splicing(args)) do
            Ctx.Core.change(entity, unquote(function.changeset_function))
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

    quote do
      @doc false
      def unquote(function.name)(unquote_splicing(args)) do
        Ctx.Core.update(unquote(function.repo_module), unquote_splicing(args))
      end
    end
  end

  # Functions (using schema 'Product' as example):

  defp generate_function(_func), do: quote(do: :ok)

  @spec core_function(map, binary) :: atom
  defp core_function(function, core_function_name) do
    function.name
    |> to_string()
    |> String.ends_with?("!")
    |> maybe_add_bang(core_function_name)
    |> String.to_atom()
  end

  @spec maybe_add_bang(boolean, binary) :: binary
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

  @spec get_option(keyword, atom) :: any
  defp get_option(opts, :create_changeset_function) do
    if opts[:create_changeset_function],
      do: opts[:create_changeset],
      else: get_option(opts, :changeset_function)
  end

  defp get_option(opts, :changeset_function) do
    if opts[:changeset_function], do: opts[:changeset_function], else: :changeset
  end
end
