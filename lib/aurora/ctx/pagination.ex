defmodule Aurora.Ctx.Pagination do
  @moduledoc """
  Struct for handling pagination state.

  ## Fields

  * `repo_module` - Repository module used for database operations
  * `schema_module` - Schema module representing the data being paginated
  * `entries_count` - Total number of records available
  * `pages_count` - Total number of pages based on entries_count and per_page
  * `page` - Current page number (default: 1)
  * `per_page` - Number of entries per page (default: 40)
  * `opts` - Additional query options passed to database operations
  * `entries` - List of records for the current page

  ## Configuration

  Default pagination settings can be configured in your `config.exs`:

      config :aurora_ctx, :pagination,
        page: 1,
        per_page: 40

  If not configured, defaults to page: 1, per_page: 40.
  """

  @type t :: %__MODULE__{
          repo_module: module() | nil,
          schema_module: module() | nil,
          entries_count: non_neg_integer() | nil,
          pages_count: pos_integer() | nil,
          page: pos_integer(),
          per_page: pos_integer(),
          opts: keyword(),
          entries: list()
        }

  defstruct [
    :repo_module,
    :schema_module,
    :entries_count,
    :pages_count,
    page: 1,
    per_page: 40,
    opts: [],
    entries: []
  ]

  @page 1
  @per_page 40
  @default_pagination Application.compile_env(:aurora_ctx, :pagination, %{})

  @doc """
  Creates a new pagination struct with safe defaults from the application configuration.
  Delegates to new/1 with the configured defaults.

  Any invalid configuration values will be replaced with system defaults:
  - page: 1
  - per_page: 40

  Returns:
    t()
  """
  @spec new() :: t()
  def new, do: new(@default_pagination)

  @doc """
  Creates a new pagination struct with the given attributes.

  Parameters:
    - attrs (map | keyword): Pagination attributes
      - :page (pos_integer): Page number (default: 1)
      - :per_page (pos_integer): Items per page (default: 40)
      - :opts (keyword): Additional query options to be passed to database operations
      - :entries (list): Initial list of entries for the current page

  Any invalid or negative values for :page or :per_page will be replaced with defaults.
  Empty or invalid :opts and :entries will be initialized as empty lists.

  Returns:
    t()
  """
  @spec new(map() | keyword()) :: t()
  def new(attrs) when is_list(attrs), do: attrs |> Enum.into(%{}) |> new()

  def new(attrs) when is_map(attrs) do
    %__MODULE__{
      page: get_positive_integer(attrs, :page, @page),
      per_page: get_positive_integer(attrs, :per_page, @per_page),
      opts: Map.get(attrs, :opts, []),
      entries: Map.get(attrs, :entries, [])
    }
  end

  ## PRIVATE

  @spec get_positive_integer(map, atom, integer) :: integer
  defp get_positive_integer(map, key, default) do
    case Map.get(map, key, default) do
      value when is_integer(value) and value > 0 -> value
      _ -> default
    end
  end
end
