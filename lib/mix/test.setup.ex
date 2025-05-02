defmodule Mix.Tasks.Test.Setup do
  @moduledoc """
  A Mix task for setting up the test environment by creating and migrating the test database.
  """

  use Mix.Task

  @doc """
  Runs the test setup task by creating and migrating the test database.

  Parameters:
  - args: list | nil - Command line arguments (not used)

  Returns:
  - any
  """
  @spec run(list | nil) :: any
  def run(_args) do
    repo = Aurora.Ctx.Repo

    Code.require_file("test/env_loader.exs")
    Code.ensure_compiled(repo)

    Mix.Task.run("ecto.create", ["-r", repo])
    Mix.Task.run("ecto.migrate", ["-r", repo])
  end
end
