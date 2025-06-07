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
    
    is_following = if Map.has_key?(socket.assigns, :current_user) && socket.assigns.current_user && socket.assigns.current_user.id != user.id do
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
    if Map.has_key?(socket.assigns, :current_user) && socket.assigns.current_user do
      case Social.follow_user(socket.assigns.current_user.id, socket.assigns.user.id) do
        {:ok, _follow} ->
          {:noreply,
           socket
           |> assign(:is_following, true)
           |> update(:follower_count, &(&1 + 1))
           |> put_flash(:info, "You are now following this user.")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Unable to follow at this time.")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("unfollow", _params, socket) do
    if Map.has_key?(socket.assigns, :current_user) && socket.assigns.current_user do
      Social.unfollow_user(socket.assigns.current_user.id, socket.assigns.user.id)

      {:noreply,
       socket
       |> assign(:is_following, false)
       |> update(:follower_count, &(&1 - 1))
       |> put_flash(:info, "You have unfollowed this user.")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="business-profile-header">
        <div class="business-profile-avatar">
          <%= String.upcase(String.first(@user.email)) %>
        </div>
        <h1 style="font-size: 2rem; font-weight: 600; color: var(--nathan-navy); margin-bottom: 0.5rem;">
          @<%= String.split(@user.email, "@") |> hd %>
        </h1>
        <div class="business-stats">
          <div class="business-stat"><strong><%= @following_count %></strong> Following</div>
          <div class="business-stat"><strong><%= @follower_count %></strong> Followers</div>
          <div class="business-stat"><strong><%= length(@posts) %></strong> Posts</div>
        </div>

        <%= if assigns[:current_user] && @current_user.id != @user.id do %>
          <div style="display: flex; gap: 1rem; margin-top: 2rem; justify-content: center;">
            <%= if @is_following do %>
              <button
                phx-click="unfollow"
                class="business-btn business-btn--secondary"
                style="padding: 0.75rem 1.5rem;"
              >
                Unfollow
              </button>
            <% else %>
              <button
                phx-click="follow"
                class="business-btn business-btn--primary"
                style="padding: 0.75rem 1.5rem;"
              >
                Follow
              </button>
            <% end %>
            <button class="business-btn business-btn--secondary" style="padding: 0.75rem 1.5rem;">
              Message
            </button>
          </div>
        <% end %>
      </div>

      <div>
        <h2 class="business-section-title">
          Posts
        </h2>

        <%= for post <- @posts do %>
          <div class="business-post">
            <div style="display: flex; align-items: center; margin-bottom: 1rem;">
              <div class="business-avatar">
                <%= String.upcase(String.first(post.user.email)) %>
              </div>
              <div style="margin-left: 1rem;">
                <div class="business-username">
                  @<%= String.split(post.user.email, "@") |> hd %>
                </div>
                <div class="business-timestamp">
                  <%= Calendar.strftime(post.inserted_at, "%B %d at %I:%M %p") %>
                </div>
              </div>
            </div>

            <%= if post.content do %>
              <div class="business-content"><%= post.content %></div>
            <% end %>

            <%= if post.image_url do %>
              <img src={post.image_url} alt="Post attachment" class="business-image" />
            <% end %>

            <div class="business-actions">
              <button class="business-action-btn">Like</button>
              <button class="business-action-btn">Comment</button>
              <button class="business-action-btn">Share</button>
            </div>
          </div>
        <% end %>

        <%= if @posts == [] do %>
          <div class="business-empty">
            <h3 style="font-size: 1.5rem; font-weight: 600; color: var(--nathan-navy); margin-bottom: 1rem;">
              No posts yet
            </h3>
            <p style="font-size: 1rem; margin-bottom: 2rem; color: var(--nathan-gray);">
              When this user shares posts, they'll appear here.
            </p>
            <%= if assigns[:current_user] && @current_user.id == @user.id do %>
              <.link navigate={~p"/posts/new"} class="business-btn business-btn--primary">
                Create your first post
              </.link>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end