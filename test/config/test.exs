import Config

checkout_root = Path.expand("../..", __DIR__)

# Every checkout (main clone or git worktree) tests against its own disposable
# PostgreSQL instance (scripts/test_pg.sh), reached through a Unix socket, so
# concurrent `mix test` runs never share a server or a database. CI keeps its
# service container (`CI` is set there); AURORA_CTX_TEST_PG=shared opts a shell
# back into the plain localhost connection below.
private_test_instance? =
  System.get_env("CI") == nil and System.get_env("AURORA_CTX_TEST_PG") != "shared"

test_database_socket =
  if private_test_instance? do
    script = Path.join(checkout_root, "scripts/test_pg.sh")

    case System.cmd(script, ["ensure"], cd: checkout_root, stderr_to_stdout: true) do
      {output, 0} ->
        [socket_dir: output |> String.trim() |> String.split("\n") |> List.last()]

      {output, status} ->
        raise "scripts/test_pg.sh ensure failed (exit #{status}):\n#{output}"
    end
  else
    []
  end

config :aurora_ctx,
       Aurora.Ctx.Repo,
       [
         database: "aurora_ctx_repo",
         username: "postgres",
         password: "postgres",
         hostname: "localhost",
         pool: Ecto.Adapters.SQL.Sandbox
       ] ++ test_database_socket

config :logger, level: :warning

config :aurora_ctx, :paginate, per_page: 40
