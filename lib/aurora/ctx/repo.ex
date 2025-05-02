defmodule Aurora.Ctx.Repo do
  @moduledoc false

  # Repo for testing purpose ONLY.
  use Ecto.Repo,
    otp_app: :aurora_ctx,
    adapter: Ecto.Adapters.Postgres
end
