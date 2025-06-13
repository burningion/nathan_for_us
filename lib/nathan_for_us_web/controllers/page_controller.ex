defmodule NathanForUsWeb.PageController do
  use NathanForUsWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end

  def redirect_to_timeline(conn, _params) do
    redirect(conn, to: ~p"/video-timeline")
  end
end
