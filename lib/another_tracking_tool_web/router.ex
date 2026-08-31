defmodule AnotherTrackingToolWeb.Router do
  use AnotherTrackingToolWeb, :router

  import AnotherTrackingToolWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AnotherTrackingToolWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
    plug AnotherTrackingToolWeb.Locale
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", AnotherTrackingToolWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", AnotherTrackingToolWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:another_tracking_tool, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: AnotherTrackingToolWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", AnotherTrackingToolWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [
        {AnotherTrackingToolWeb.UserAuth, :require_authenticated},
        AnotherTrackingToolWeb.Locale
      ] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
      live "/feed", FeedLive, :index
      live "/watchlist", WatchlistLive, :index
      live "/import", ImportLive, :index
      live "/search", SearchLive, :index
      live "/media/:id", MediaLive.Show, :show
    end

    live_session :require_admin,
      on_mount: [
        {AnotherTrackingToolWeb.UserAuth, :require_authenticated},
        {AnotherTrackingToolWeb.UserAuth, :require_admin},
        AnotherTrackingToolWeb.Locale
      ] do
      live "/invites", InviteLive, :index
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", AnotherTrackingToolWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [
        {AnotherTrackingToolWeb.UserAuth, :mount_current_scope},
        AnotherTrackingToolWeb.Locale
      ] do
      live "/users/register", UserLive.Registration, :new
      live "/users/register/:code", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
