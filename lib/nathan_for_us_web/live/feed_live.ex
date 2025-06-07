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
      <div class="business-hero">
        <h1 class="business-title">The Business Understander</h1>
        <p class="business-subtitle">"I graduated from one of Canada's top business schools with really good grades."</p>
        <p style="font-size: 1.2rem; color: var(--nathan-navy); margin-top: 1rem;">
          Where serious professionals share revolutionary business strategies
        </p>
      </div>

      <%= if assigns[:current_user] do %>
        <div style="margin-bottom: 2rem;">
          <.link navigate={~p"/posts/new"} class="business-btn business-btn--primary" style="padding: 1rem 2rem; font-size: 1.1rem;">
            🚀 Share Your Business Wisdom
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
                <img src={post.image_url} alt="Business insight visualization" class="business-image" />
              <% end %>

              <div class="business-actions">
                <button class="business-action-btn">👍 Professional Endorsement</button>
                <button class="business-action-btn">💼 Business Excellence</button>
                <button class="business-action-btn">🤝 Strategic Partnership</button>
                <button class="business-action-btn">📈 Revenue Potential</button>
              </div>
            </div>
          <% end %>

          <%= if @posts == [] do %>
            <div class="business-empty">
              <div class="business-empty-icon">🤝</div>
              <h3 style="font-size: 1.5rem; font-weight: 700; color: var(--nathan-navy); margin-bottom: 1rem;">
                No business insights yet!
              </h3>
              <p style="font-size: 1.1rem; margin-bottom: 2rem;">
                Follow other business professionals to see their revolutionary strategies and ideas.
              </p>
              <.link navigate={~p"/users/register"} class="business-btn business-btn--primary">
                Expand Your Network
              </.link>
            </div>
          <% end %>
        </div>
      <% else %>
        <div class="business-card">
          <div class="business-card-header">
            <h2 style="font-size: 2rem; font-weight: 800; color: var(--nathan-navy); margin: 0;">
              🎯 Welcome to The Business Understander
            </h2>
          </div>
          <div class="business-card-body">
            <p style="font-size: 1.3rem; line-height: 1.7; margin-bottom: 2rem; color: var(--nathan-navy);">
              The most exclusive social network for <strong>serious business professionals</strong> who understand 
              that success comes from thinking outside the conventional business paradigm.
            </p>
            
            <div style="background: var(--nathan-beige); padding: 1.5rem; border-radius: 8px; margin-bottom: 2rem; border: 2px solid var(--nathan-brown);">
              <h3 style="color: var(--nathan-navy); font-weight: 700; margin-bottom: 1rem;">Platform Features:</h3>
              <ul style="color: var(--nathan-gray); line-height: 1.8;">
                <li>💡 Share revolutionary business strategies</li>
                <li>🤝 Network with fellow business understanders</li>
                <li>📊 Exchange proven methodologies</li>
                <li>🎯 Discover unconventional success approaches</li>
              </ul>
            </div>

            <div class="business-cta">
              <.link navigate={~p"/users/register"} class="business-btn business-btn--success" style="padding: 1rem 2rem; font-size: 1.1rem;">
                🚀 Join the Business Elite
              </.link>
              <.link navigate={~p"/users/log_in"} class="business-btn business-btn--primary" style="padding: 1rem 2rem; font-size: 1.1rem;">
                🔐 Access Your Account
              </.link>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end