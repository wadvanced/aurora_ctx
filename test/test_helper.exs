Code.require_file("test/env_loader.exs")

ExUnit.start()

{:ok, _} = Application.ensure_all_started(:ecto_sql)

Aurora.Ctx.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(Aurora.Ctx.Repo, :manual)
