defmodule NathanForUsWeb.SkeetsLive do
  use NathanForUsWeb, :live_view

  alias NathanForUs.Social


  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(NathanForUs.PubSub, "nathan_fielder_skeets")
    end

    bluesky_posts = Social.list_bluesky_posts_with_users(limit: 50)

    {:ok, assign(socket, 
      bluesky_posts: bluesky_posts, 
      page_title: "Nathan Fielder: Mention Log",
      page_description: "What is in the news about Nathan Fielder on Bluesky")}
  end

  def handle_info({:new_nathan_fielder_skeet, post}, socket) do
    {:noreply, update(socket, :bluesky_posts, fn posts -> [post | posts] end)}
  end

  defp convert_thumb_url(thumb) when is_binary(thumb) do
    # If it starts with http, it's already a full URL
    if String.starts_with?(thumb, "http") do
      thumb
    else
      # Convert blob CID to CDN URL - try the format Bluesky web client uses
      "https://cdn.bsky.app/img/feed_thumbnail/plain/#{thumb}@jpeg"
    end
  end
  defp convert_thumb_url(_), do: nil

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-zinc-50 text-zinc-900 p-6 font-mono">
      <div class="max-w-5xl mx-auto">
        <.page_header posts_count={length(@bluesky_posts)} />
        
        <div class="space-y-4">
          <.post_list posts={@bluesky_posts} />
          <.empty_state :if={@bluesky_posts == []} />
        </div>
      </div>
    </div>
    """
  end

  # Page header component
  defp page_header(assigns) do
    ~H"""
    <div class="mb-8 border-b border-zinc-300 pb-6">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold text-blue-600 mb-1">MENTION LOG</h1>
        </div>
        <div class="text-right text-xs text-zinc-500">
          <div>STATUS: MONITORING</div>
          <div>ENTRIES: <%= @posts_count %></div>
        </div>
      </div>
    </div>
    """
  end

  # Post list component
  defp post_list(assigns) do
    ~H"""
    <%= for post <- @posts do %>
      <.post_card post={post} />
    <% end %>
    """
  end

  # Individual post card component
  defp post_card(assigns) do
    ~H"""
    <div class="bg-white border border-zinc-300 rounded-lg p-4 hover:bg-zinc-50 transition-colors shadow-sm">
      <.post_header post={@post} />
      <.post_content :if={@post.record_text} text={@post.record_text} />
      <.post_embed :if={@post.embed_type} post={@post} />
      <.post_footer post={@post} />
    </div>
    """
  end

  # Post header with timestamp and user info
  defp post_header(assigns) do
    ~H"""
    <div class="flex items-start justify-between mb-3">
      <div class="text-zinc-500 text-xs">
        STARDATE: <.timestamp post={@post} />
      </div>
      <.user_info :if={@post.bluesky_user} user={@post.bluesky_user} />
    </div>
    """
  end

  # Timestamp component
  defp timestamp(assigns) do
    ~H"""
    <%= if @post.record_created_at do %>
      <%= Calendar.strftime(@post.record_created_at, "%Y.%m.%d %H:%M") %>
    <% else %>
      <%= Calendar.strftime(@post.inserted_at, "%Y.%m.%d %H:%M") %>
    <% end %>
    """
  end

  # User info component
  defp user_info(assigns) do
    ~H"""
    <div class="flex items-center space-x-2">
      <.avatar :if={@user.avatar_url} url={@user.avatar_url} />
      <div class="text-xs text-zinc-600">
        <%= @user.display_name || @user.handle || "UNKNOWN" %>
      </div>
    </div>
    """
  end

  # Avatar component
  defp avatar(assigns) do
    ~H"""
    <img src={@url} alt="Avatar" class="w-6 h-6 rounded object-cover border border-zinc-300" />
    """
  end

  # Post content component
  defp post_content(assigns) do
    ~H"""
    <div class="text-zinc-800 leading-relaxed text-sm mb-3 pl-4 border-l-2 border-blue-600">
      <%= @text %>
    </div>
    """
  end

  # Post embed component
  defp post_embed(assigns) do
    ~H"""
    <div class="mt-3 p-3 bg-zinc-100 border border-zinc-200 rounded">
      <div class="text-xs text-blue-600 uppercase mb-2">ATTACHMENT: <%= @post.embed_type %></div>
      <.embed_content post={@post} />
    </div>
    """
  end

  # Embed content switcher
  defp embed_content(%{post: %{embed_type: "external"}} = assigns) do
    ~H"""
    <.external_embed post={@post} />
    """
  end

  defp embed_content(%{post: %{embed_type: "images"}} = assigns) do
    ~H"""
    <.images_embed post={@post} />
    """
  end

  defp embed_content(%{post: %{embed_type: "video"}} = assigns) do
    ~H"""
    <.video_embed post={@post} />
    """
  end

  defp embed_content(assigns), do: ~H""

  # External link embed component
  defp external_embed(assigns) do
    ~H"""
    <div class="border-l-2 border-blue-600 pl-3">
      <.embed_title :if={@post.embed_title} post={@post} />
      <.embed_description :if={@post.embed_description} description={@post.embed_description} />
      <.embed_url :if={@post.embed_uri} uri={@post.embed_uri} />
    </div>
    """
  end

  # Images embed component
  defp images_embed(assigns) do
    ~H"""
    <div :if={@post.embed_uri} class="flex items-center space-x-2">
      <img src={convert_thumb_url(@post.embed_uri)} alt={@post.embed_title || "Image"} class="w-20 h-16 object-cover rounded border border-zinc-300" />
      <.embed_caption :if={@post.embed_title} title={@post.embed_title} />
    </div>
    """
  end

  # Video embed component
  defp video_embed(assigns) do
    ~H"""
    <div class="flex items-center space-x-2">
      <.video_thumbnail :if={@post.embed_thumb} thumb={@post.embed_thumb} title={@post.embed_title} />
      <.embed_caption :if={@post.embed_title} title={@post.embed_title} />
    </div>
    """
  end

  # Video thumbnail with play button
  defp video_thumbnail(assigns) do
    ~H"""
    <div class="relative">
      <img src={convert_thumb_url(@thumb)} alt={@title || "Video"} class="w-20 h-16 object-cover rounded border border-zinc-300" />
      <div class="absolute inset-0 flex items-center justify-center">
        <div class="bg-black bg-opacity-70 rounded-full p-1">
          <svg class="w-3 h-3 text-blue-600" fill="currentColor" viewBox="0 0 20 20">
            <path d="M8 5v10l8-5-8-5z"/>
          </svg>
        </div>
      </div>
    </div>
    """
  end

  # Embed title component
  defp embed_title(assigns) do
    ~H"""
    <div class="text-zinc-800 text-sm font-medium">
      <.link :if={@post.embed_uri} href={@post.embed_uri} target="_blank" class="hover:text-blue-600">
        <%= @post.embed_title %>
      </.link>
      <span :if={!@post.embed_uri}><%= @post.embed_title %></span>
    </div>
    """
  end

  # Embed description component
  defp embed_description(assigns) do
    ~H"""
    <div class="text-zinc-600 text-xs mt-1 line-clamp-2"><%= @description %></div>
    """
  end

  # Embed URL component
  defp embed_url(assigns) do
    ~H"""
    <div class="text-blue-600 text-xs mt-1">
      <%= URI.parse(@uri).host || @uri %>
    </div>
    """
  end

  # Embed caption component
  defp embed_caption(assigns) do
    ~H"""
    <div class="text-zinc-600 text-xs"><%= @title %></div>
    """
  end

  # Post footer with metadata and source link
  defp post_footer(assigns) do
    ~H"""
    <div class="flex items-center justify-between mt-3 pt-3 border-t border-zinc-200">
      <.post_metadata post={@post} />
      <.source_link post={@post} />
    </div>
    """
  end

  # Post metadata component
  defp post_metadata(assigns) do
    ~H"""
    <div class="flex items-center space-x-4 text-xs text-zinc-500">
      <span>ID: <%= String.slice(@post.cid, 0, 8) %></span>
      <span :if={@post.record_langs}>LANG: <%= Enum.join(@post.record_langs, ",") %></span>
    </div>
    """
  end

  # Source link component
  defp source_link(assigns) do
    has_source = assigns.post.bluesky_user && assigns.post.bluesky_user.handle && assigns.post.rkey
    assigns = assign(assigns, :has_source, has_source)
    
    ~H"""
    <.link 
      :if={@has_source}
      href={"https://bsky.app/profile/#{@post.bluesky_user.handle}/post/#{@post.rkey}"} 
      target="_blank" 
      class="text-blue-600 hover:text-blue-500 text-xs font-medium"
    >
      VIEW SOURCE →
    </.link>
    <span :if={!@has_source} class="text-zinc-400 text-xs">No source available</span>
    """
  end

  # Empty state component
  defp empty_state(assigns) do
    ~H"""
    <div class="bg-white border border-zinc-300 rounded-lg p-8 text-center shadow-sm">
      <div class="text-blue-600 text-lg mb-2">
        NO ENTRIES LOGGED
      </div>
      <p class="text-zinc-600 text-sm">
        Monitoring systems are active. Intelligence will appear here when Nathan Fielder mentions are detected.
      </p>
    </div>
    """
  end
end