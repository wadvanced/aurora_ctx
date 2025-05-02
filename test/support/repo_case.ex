defmodule Aurora.Ctx.Test.RepoCase do
  @moduledoc """
  This module provides a test case template for database-related tests.
  It sets up the Ecto sandbox for test isolation and provides common imports
  for database operations.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      alias Aurora.Ctx.Repo

      import Ecto
      import Ecto.Query
      import Aurora.Ctx.Test.RepoCase
      import Aurora.Ctx.Test.Support.Helper
    end
  end

  setup tags do
    pid = Sandbox.start_owner!(Aurora.Ctx.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
    :ok
  end
end
