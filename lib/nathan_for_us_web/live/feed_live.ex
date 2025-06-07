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
    <div>
      <%= if assigns[:current_user] do %>
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
      <% else %>
        <div style="max-width: 600px; margin: 0 auto; padding: 3rem 1.5rem; text-align: center;">
          <h1 style="font-size: 2.5rem; font-weight: 300; color: var(--nathan-navy); margin-bottom: 1.5rem; line-height: 1.2;">
            Connect with professionals who understand business
          </h1>
          <p style="font-size: 1.2rem; line-height: 1.6; margin-bottom: 3rem; color: var(--nathan-gray); max-width: 500px; margin-left: auto; margin-right: auto;">
            A platform for sharing insights, strategies, and connecting with like-minded business professionals.
          </p>
          
          <div style="display: flex; gap: 1rem; justify-content: center; flex-wrap: wrap;">
            <.link navigate={~p"/users/register"} class="business-btn business-btn--primary" style="padding: 1rem 2rem; font-size: 1.1rem;">
              Get Started
            </.link>
            <.link navigate={~p"/users/log_in"} class="business-btn business-btn--secondary" style="padding: 1rem 2rem; font-size: 1.1rem;">
              Log In
            </.link>
          </div>

          <div style="margin-top: 4rem; padding-top: 3rem; border-top: 1px solid #e2e8f0;">
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 2rem; max-width: 800px; margin: 0 auto;">
              <div style="text-align: left;">
                <h3 style="font-size: 1.1rem; font-weight: 600; color: var(--nathan-navy); margin-bottom: 0.5rem;">Share Ideas</h3>
                <p style="color: var(--nathan-gray); line-height: 1.5;">Post your business insights and strategies with the community.</p>
              </div>
              <div style="text-align: left;">
                <h3 style="font-size: 1.1rem; font-weight: 600; color: var(--nathan-navy); margin-bottom: 0.5rem;">Build Network</h3>
                <p style="color: var(--nathan-gray); line-height: 1.5;">Connect with other professionals in your industry.</p>
              </div>
              <div style="text-align: left;">
                <h3 style="font-size: 1.1rem; font-weight: 600; color: var(--nathan-navy); margin-bottom: 0.5rem;">Learn & Grow</h3>
                <p style="color: var(--nathan-gray); line-height: 1.5;">Discover new perspectives and business approaches.</p>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end