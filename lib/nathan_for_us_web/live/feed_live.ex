defmodule NathanForUsWeb.FeedLive do
  use NathanForUsWeb, :live_view

  alias NathanForUs.Social

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(NathanForUs.PubSub, "posts")
    end

    posts = if socket.assigns.current_user do
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
    <div class="max-w-2xl mx-auto p-4">
      <div class="text-center mb-8">
        <h1 class="text-3xl font-bold text-yellow-600 mb-2">The Business Understander</h1>
        <p class="text-gray-600 italic">"I graduated from one of Canada's top business schools with really good grades."</p>
      </div>

      <%= if @current_user do %>
        <div class="mb-6">
          <.link navigate={~p"/posts/new"} class="bg-yellow-500 hover:bg-yellow-600 text-black font-bold py-2 px-4 rounded border-2 border-black shadow-md transform hover:translate-y-[-2px] transition-all">
            Share a Business Idea
          </.link>
        </div>

        <div class="space-y-6">
          <%= for post <- @posts do %>
            <div class="bg-white border-2 border-gray-300 rounded-lg p-4 shadow-lg">
              <div class="flex items-center mb-3">
                <div class="w-10 h-10 bg-yellow-400 rounded-full flex items-center justify-center border-2 border-black">
                  <span class="text-black font-bold text-sm">
                    <%= String.upcase(String.first(post.user.email)) %>
                  </span>
                </div>
                <div class="ml-3">
                  <.link navigate={~p"/users/#{post.user.id}"} class="font-bold text-blue-600 hover:underline">
                    @<%= String.split(post.user.email, "@") |> hd %>
                  </.link>
                  <p class="text-gray-500 text-sm">
                    <%= Calendar.strftime(post.inserted_at, "%B %d at %I:%M %p") %>
                  </p>
                </div>
              </div>

              <%= if post.content do %>
                <p class="text-gray-800 mb-3 leading-relaxed"><%= post.content %></p>
              <% end %>

              <%= if post.image_url do %>
                <img src={post.image_url} alt="Post image" class="w-full rounded border-2 border-gray-200 mb-3" />
              <% end %>

              <div class="flex space-x-4 text-sm text-gray-500">
                <button class="hover:text-yellow-600 transition-colors">👍 Endorse</button>
                <button class="hover:text-yellow-600 transition-colors">💼 Very Professional</button>
                <button class="hover:text-yellow-600 transition-colors">🤝 Great for Business</button>
              </div>
            </div>
          <% end %>

          <%= if @posts == [] do %>
            <div class="text-center py-12">
              <div class="text-6xl mb-4">🤝</div>
              <h3 class="text-xl font-bold text-gray-700 mb-2">No posts yet!</h3>
              <p class="text-gray-500">Follow some business-minded individuals to see their ideas here.</p>
            </div>
          <% end %>
        </div>
      <% else %>
        <div class="text-center py-12">
          <div class="text-6xl mb-4">💼</div>
          <h3 class="text-xl font-bold text-gray-700 mb-2">Welcome to The Business Understander</h3>
          <p class="text-gray-500 mb-6">The premier social network for serious business professionals.</p>
          <div class="space-x-4">
            <.link navigate={~p"/users/log_in"} class="bg-yellow-500 hover:bg-yellow-600 text-black font-bold py-2 px-4 rounded border-2 border-black">
              Log In
            </.link>
            <.link navigate={~p"/users/register"} class="bg-blue-500 hover:bg-blue-600 text-white font-bold py-2 px-4 rounded border-2 border-black">
              Sign Up
            </.link>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end