defmodule NathanForUsWeb.SkeetsLive do
  use NathanForUsWeb, :live_view

  alias NathanForUs.Social

  on_mount {NathanForUsWeb.UserAuth, :ensure_authenticated}

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

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-zinc-50 text-zinc-900 p-6 font-mono">
      <div class="max-w-5xl mx-auto">
        <div class="mb-8 border-b border-zinc-300 pb-6">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-2xl font-bold text-blue-600 mb-1">MENTION LOG</h1>
            </div>
            <div class="text-right text-xs text-zinc-500">
              <div>STATUS: MONITORING</div>
              <div>ENTRIES: <%= length(@bluesky_posts) %></div>
            </div>
          </div>
        </div>

        <div class="space-y-4">
          <%= for post <- @bluesky_posts do %>
            <div class="bg-white border border-zinc-300 rounded-lg p-4 hover:bg-zinc-50 transition-colors shadow-sm">
              <div class="flex items-start justify-between mb-3">
                <div class="text-zinc-500 text-xs">
                  STARDATE: <%= if post.record_created_at do %>
                    <%= Calendar.strftime(post.record_created_at, "%Y.%m.%d %H:%M") %>
                  <% else %>
                    <%= Calendar.strftime(post.inserted_at, "%Y.%m.%d %H:%M") %>
                  <% end %>
                </div>
                <div class="flex items-center space-x-2">
                  <%= if post.bluesky_user && post.bluesky_user.avatar_url do %>
                    <img src={post.bluesky_user.avatar_url} alt="Avatar" class="w-6 h-6 rounded object-cover border border-zinc-300" />
                  <% end %>
                  <div class="text-xs text-zinc-600">
                    <%= if post.bluesky_user do %>
                      <%= post.bluesky_user.display_name || post.bluesky_user.handle || "UNKNOWN" %>
                    <% else %>
                      UNKNOWN OPERATOR
                    <% end %>
                  </div>
                </div>
              </div>

              <%= if post.record_text do %>
                <div class="text-zinc-800 leading-relaxed text-sm mb-3 pl-4 border-l-2 border-blue-600">
                  <%= post.record_text %>
                </div>
              <% end %>

              <%= if post.embed_type do %>
                <div class="mt-3 p-3 bg-zinc-100 border border-zinc-200 rounded">
                  <div class="text-xs text-blue-600 uppercase mb-2">ATTACHMENT: <%= post.embed_type %></div>
                  <%= case post.embed_type do %>
                    <% "external" -> %>
                      <div class="flex items-start space-x-3">
                        <%= if post.embed_thumb do %>
                          <img src={post.embed_thumb} alt={post.embed_title || "Attachment"} class="w-16 h-12 object-cover rounded border border-zinc-300" />
                        <% end %>
                        <div class="flex-1 min-w-0">
                          <%= if post.embed_title do %>
                            <div class="text-zinc-800 text-sm font-medium truncate">
                              <%= if post.embed_uri do %>
                                <a href={post.embed_uri} target="_blank" class="hover:text-blue-600">
                                  <%= post.embed_title %>
                                </a>
                              <% else %>
                                <%= post.embed_title %>
                              <% end %>
                            </div>
                          <% end %>
                          <%= if post.embed_description do %>
                            <div class="text-zinc-600 text-xs mt-1 line-clamp-2"><%= post.embed_description %></div>
                          <% end %>
                          <%= if post.embed_uri do %>
                            <div class="text-blue-600 text-xs mt-1">
                              <%= URI.parse(post.embed_uri).host || post.embed_uri %>
                            </div>
                          <% end %>
                        </div>
                      </div>
                    <% "images" -> %>
                      <%= if post.embed_uri do %>
                        <div class="flex items-center space-x-2">
                          <img src={post.embed_uri} alt={post.embed_title || "Image"} class="w-20 h-16 object-cover rounded border border-zinc-300" />
                          <%= if post.embed_title do %>
                            <div class="text-zinc-600 text-xs"><%= post.embed_title %></div>
                          <% end %>
                        </div>
                      <% end %>
                    <% "video" -> %>
                      <div class="flex items-center space-x-2">
                        <%= if post.embed_thumb do %>
                          <div class="relative">
                            <img src={post.embed_thumb} alt={post.embed_title || "Video"} class="w-20 h-16 object-cover rounded border border-zinc-300" />
                            <div class="absolute inset-0 flex items-center justify-center">
                              <div class="bg-black bg-opacity-70 rounded-full p-1">
                                <svg class="w-3 h-3 text-blue-600" fill="currentColor" viewBox="0 0 20 20">
                                  <path d="M8 5v10l8-5-8-5z"/>
                                </svg>
                              </div>
                            </div>
                          </div>
                        <% end %>
                        <%= if post.embed_title do %>
                          <div class="text-zinc-600 text-xs"><%= post.embed_title %></div>
                        <% end %>
                      </div>
                  <% end %>
                </div>
              <% end %>

              <div class="flex items-center justify-between mt-3 pt-3 border-t border-zinc-200">
                <div class="flex items-center space-x-4 text-xs text-zinc-500">
                  <span>ID: <%= String.slice(post.cid, 0, 8) %></span>
                  <%= if post.record_langs do %>
                    <span>LANG: <%= Enum.join(post.record_langs, ",") %></span>
                  <% end %>
                </div>
                <%= if post.bluesky_user && post.bluesky_user.handle && post.rkey do %>
                  <a 
                    href={"https://bsky.app/profile/#{post.bluesky_user.handle}/post/#{post.rkey}"} 
                    target="_blank" 
                    class="text-blue-600 hover:text-blue-500 text-xs font-medium"
                  >
                    VIEW SOURCE →
                  </a>
                <% else %>
                  <span class="text-zinc-400 text-xs">No source available</span>
                <% end %>
              </div>
            </div>
          <% end %>

          <%= if @bluesky_posts == [] do %>
            <div class="bg-white border border-zinc-300 rounded-lg p-8 text-center shadow-sm">
              <div class="text-blue-600 text-lg mb-2">
                NO ENTRIES LOGGED
              </div>
              <p class="text-zinc-600 text-sm">
                Monitoring systems are active. Intelligence will appear here when Nathan Fielder mentions are detected.
              </p>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end