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
    <div>
        <div style="margin-bottom: 2rem;">
          <.link navigate={~p"/posts/new"} class="business-btn business-btn--primary">
            New Post
          </.link>
        </div>

        <div>
          <%= for post <- @posts do %>
            <div class="business-post">
              <div style="display: flex; align-items: center; margin-bottom: 1rem;">
                <div class="business-avatar">
                  <%= String.upcase(String.first(post.user.email)) %>
                </div>
                <div style="margin-left: 1rem;">
                  <.link navigate={~p"/users/#{post.user.id}"} class="business-username">
                    @<%= String.split(post.user.email, "@") |> hd %>
                  </.link>
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
                Welcome to your feed
              </h3>
              <p style="font-size: 1rem; margin-bottom: 2rem; color: var(--nathan-gray);">
                Follow other users to see their posts here.
              </p>
            </div>
          <% end %>
        </div>
    </div>
    <% else %>
        <div style="
          height: 100vh;
          display: flex;
          align-items: flex-start;
          justify-content: center;
          text-align: center;
          background: linear-gradient(135deg, #f8fafc 0%, #e2e8f0 100%);
          padding-top: 10vh;
        ">
          <div style="max-width: 800px; padding: 0 2rem;">
            <h1 style="
              font-size: clamp(2.5rem, 7vw, 5rem);
              font-weight: 400;
              color: #1a202c;
              margin-bottom: 4rem;
              letter-spacing: -0.025em;
              line-height: 1.1;
            ">
              Do you enjoy<br>Nathan Fielder?
            </h1>

            <.link
              navigate={~p"/users/register"}
              style="
                display: inline-block;
                background: #1a202c;
                color: white;
                padding: 1rem 3rem;
                font-size: 1.125rem;
                font-weight: 500;
                text-decoration: none;
                border-radius: 8px;
                transition: all 0.2s ease;
                box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
              "
              onmouseover="this.style.background='#2d3748'; this.style.transform='translateY(-2px)'"
              onmouseout="this.style.background='#1a202c'; this.style.transform='translateY(0)'"
            >
              Yes? Join Us.
            </.link>
          </div>
        </div>
    <% end %>
    """
  end
end
