defmodule NathanForUsWeb.FeedLive do
  use NathanForUsWeb, :live_view

  alias NathanForUs.Social

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(NathanForUs.PubSub, "posts")
    end

    posts = if Map.has_key?(socket.assigns, :current_user) && socket.assigns.current_user do
      Social.list_feed_posts(socket.assigns.current_user.id)
    else
      []
    end

    {:ok, assign(socket, posts: posts, page_title: "The Business Understander")}
  end

  @impl true
  def handle_info({:post_created, post}, socket) do
    {:noreply, update(socket, :posts, fn posts -> [post | posts] end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= if assigns[:current_user] do %>
    <div class="min-h-screen bg-gradient-to-br from-gray-50 to-gray-200 p-6">
      <div class="max-w-2xl mx-auto">
        <div class="mb-8">
          <.link navigate={~p"/posts/new"} class="inline-block bg-gray-900 text-white px-6 py-3 rounded-lg font-medium hover:bg-gray-800 transition-colors">
            Share something
          </.link>
        </div>

        <div class="space-y-6">
          <%= for post <- @posts do %>
            <div class="bg-white rounded-lg p-6 shadow-sm border border-gray-200">
              <div class="flex items-center mb-4">
                <div class="w-12 h-12 bg-gray-900 text-white rounded-full flex items-center justify-center font-medium text-lg">
                  <%= String.upcase(String.first(post.user.email)) %>
                </div>
                <div class="ml-4">
                  <.link navigate={~p"/users/#{post.user.id}"} class="font-medium text-gray-900 hover:underline">
                    @<%= String.split(post.user.email, "@") |> hd %>
                  </.link>
                  <div class="text-sm text-gray-500">
                    <%= Calendar.strftime(post.inserted_at, "%B %d at %I:%M %p") %>
                  </div>
                </div>
              </div>

              <%= if post.content do %>
                <div class="text-gray-900 mb-4 leading-relaxed"><%= post.content %></div>
              <% end %>

              <%= if post.image_url do %>
                <img src={post.image_url} alt="Post attachment" class="w-full rounded-lg mb-4" />
              <% end %>

              <div class="flex space-x-6 text-sm text-gray-500">
                <button class="hover:text-gray-700 transition-colors">Like</button>
                <button class="hover:text-gray-700 transition-colors">Comment</button>
                <button class="hover:text-gray-700 transition-colors">Share</button>
              </div>
            </div>
          <% end %>

          <%= if @posts == [] do %>
            <div class="text-center py-12">
              <h3 class="text-2xl font-normal text-gray-900 mb-4">
                Your professional network awaits
              </h3>
              <p class="text-gray-600 mb-6">
                Follow other business understanders to see their insights.
              </p>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    <% else %>
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
    <% end %>
    """
  end
end
