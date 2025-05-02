defmodule Aurora.Ctx.Pagination do
  @moduledoc """
  Struct for handling pagination state.

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
  Creates a new pagination struct with safe defaults.

  Returns:
    t()
  """
  @spec new() :: t()
  def new, do: new(@default_pagination)

  @doc """
  Creates a new pagination struct with safe defaults.

  Parameters:
    - attrs (map | keyword): Pagination attributes
      - :page (pos_integer): Page number (default: 1)
      - :per_page (pos_integer): Items per page (default: 40)

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
