defmodule NathanForUsWeb.FeedLive do
  use NathanForUsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if Map.has_key?(socket.assigns, :current_user) && socket.assigns.current_user do
      {:ok, redirect(socket, to: ~p"/stay-tuned")}
    else
      {:ok, assign(socket, page_title: "Nathan For Us")}
    end
  end

  @impl true
  def handle_info({:post_created, post}, socket) do
    {:noreply, update(socket, :posts, fn posts -> [post | posts] end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-gray-50 to-gray-200 flex items-start justify-center pt-[10vh] text-center">
      <div class="max-w-4xl px-8">
        <img src={~p"/images/fellow-pilot.png"} alt="Nathan Fielder" style="max-width: 100%; height: auto; margin: 0 auto 3rem auto; display: block;" />
        <h1 class="text-5xl md:text-7xl lg:text-8xl font-normal text-gray-900 mb-16 leading-tight tracking-tight">
          Do you enjoy<br>Nathan Fielder?
        </h1>

        <.link
          navigate={~p"/users/register"}
          class="inline-block bg-gray-900 text-white px-12 py-4 text-xl font-medium rounded-lg hover:bg-gray-800 transition-all duration-200 hover:-translate-y-0.5 shadow-lg"
        >
          Yes
        </.link>
      </div>
    </div>
    """
  end
end
