defmodule AnotherTrackingTool.Repo do
  use Ecto.Repo,
    otp_app: :another_tracking_tool,
    adapter: Ecto.Adapters.Postgres
end
