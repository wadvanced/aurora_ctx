import Config

config :aurora_ctx, Aurora.Ctx.Repo,
  database: "aurora_ctx_repo",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :logger, level: :warning

config :aurora_ctx, :paginate, per_page: 40
