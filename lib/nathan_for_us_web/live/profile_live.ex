defmodule NathanForUsWeb.ProfileLive do
  use NathanForUsWeb, :live_view

  alias NathanForUs.Social
  alias NathanForUs.Accounts

  @impl true
  def mount(%{"id" => user_id}, _session, socket) do
    user = Accounts.get_user!(user_id)
    posts = Social.list_user_posts(user_id)
    
    follower_count = Social.get_follower_count(user_id)
    following_count = Social.get_following_count(user_id)
    
    is_following = if socket.assigns.current_user && socket.assigns.current_user.id != user.id do
      Social.following?(socket.assigns.current_user.id, user.id)
    else
      false
    end

    {:ok,
     socket
     |> assign(:user, user)
     |> assign(:posts, posts)
     |> assign(:follower_count, follower_count)
     |> assign(:following_count, following_count)
     |> assign(:is_following, is_following)
     |> assign(:page_title, "@#{String.split(user.email, "@") |> hd}")}
  end

  @impl true
  def handle_event("follow", _params, socket) do
    case Social.follow_user(socket.assigns.current_user.id, socket.assigns.user.id) do
      {:ok, _follow} ->
        {:noreply,
         socket
         |> assign(:is_following, true)
         |> update(:follower_count, &(&1 + 1))
         |> put_flash(:info, "You are now following this business professional!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Unable to follow at this time.")}
    end
  end

  @impl true
  def handle_event("unfollow", _params, socket) do
    Social.unfollow_user(socket.assigns.current_user.id, socket.assigns.user.id)

    {:noreply,
     socket
     |> assign(:is_following, false)
     |> update(:follower_count, &(&1 - 1))
     |> put_flash(:info, "You have unfollowed this user.")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto p-4">
      <div class="bg-white border-2 border-gray-300 rounded-lg p-6 shadow-lg mb-6">
        <div class="flex items-center space-x-4 mb-4">
          <div class="w-20 h-20 bg-yellow-400 rounded-full flex items-center justify-center border-4 border-black">
            <span class="text-black font-bold text-2xl">
              <%= String.upcase(String.first(@user.email)) %>
            </span>
          </div>
          <div class="flex-1">
            <h1 class="text-2xl font-bold text-gray-800">
              @<%= String.split(@user.email, "@") |> hd %>
            </h1>
            <p class="text-gray-600">Business Professional</p>
            <div class="flex space-x-4 mt-2 text-sm">
              <span><strong><%= @following_count %></strong> Following</span>
              <span><strong><%= @follower_count %></strong> Followers</span>
              <span><strong><%= length(@posts) %></strong> Business Ideas</span>
            </div>
          </div>
        </div>

        <%= if @current_user && @current_user.id != @user.id do %>
          <div class="flex space-x-3">
            <%= if @is_following do %>
              <button
                phx-click="unfollow"
                class="bg-gray-200 hover:bg-gray-300 text-gray-700 font-bold py-2 px-4 rounded border-2 border-gray-400"
              >
                Unfollow
              </button>
            <% else %>
              <button
                phx-click="follow"
                class="bg-yellow-500 hover:bg-yellow-600 text-black font-bold py-2 px-4 rounded border-2 border-black transform hover:translate-y-[-2px] transition-all"
              >
                Follow
              </button>
            <% end %>
            <button class="bg-blue-500 hover:bg-blue-600 text-white font-bold py-2 px-4 rounded border-2 border-black">
              Send Business Message
            </button>
          </div>
        <% end %>
      </div>

      <div class="space-y-6">
        <h2 class="text-xl font-bold text-gray-800 border-b-2 border-yellow-500 pb-2">
          Business Ideas & Insights
        </h2>

        <%= for post <- @posts do %>
          <div class="bg-white border-2 border-gray-300 rounded-lg p-4 shadow-lg">
            <div class="flex items-center mb-3">
              <div class="w-10 h-10 bg-yellow-400 rounded-full flex items-center justify-center border-2 border-black">
                <span class="text-black font-bold text-sm">
                  <%= String.upcase(String.first(post.user.email)) %>
                </span>
              </div>
              <div class="ml-3">
                <p class="font-bold text-blue-600">
                  @<%= String.split(post.user.email, "@") |> hd %>
                </p>
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
            <div class="text-6xl mb-4">📊</div>
            <h3 class="text-xl font-bold text-gray-700 mb-2">No posts yet!</h3>
            <p class="text-gray-500">This business professional hasn't shared any insights yet.</p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end