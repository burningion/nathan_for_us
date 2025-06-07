defmodule NathanForUs.Repo do
  use Ecto.Repo,
    otp_app: :nathan_for_us,
    adapter: Ecto.Adapters.Postgres
end
