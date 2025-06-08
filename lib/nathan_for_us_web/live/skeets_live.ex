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
      page_title: "Nathan Fielder: In Skeets",
      page_description: "What is in the news about Nathan Fielder on Bluesky")}
  end

  def handle_info({:new_nathan_fielder_skeet, post}, socket) do
    {:noreply, update(socket, :bluesky_posts, fn posts -> [post | posts] end)}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-zinc-50 p-6">
      <div class="max-w-4xl mx-auto">
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-zinc-900 mb-2">Nathan Fielder: In Skeets</h1>
          <p class="text-zinc-600">What is in the news about Nathan Fielder on Bluesky</p>
        </div>

        <div class="space-y-6">
          <%= for post <- @bluesky_posts do %>
            <div class="bg-white rounded-2xl p-6 shadow-sm border border-zinc-200">
              <div class="flex items-start justify-between mb-4">
                <div class="flex items-center space-x-3">
                  <%= if post.bluesky_user && post.bluesky_user.avatar_url do %>
                    <img src={post.bluesky_user.avatar_url} alt="Avatar" class="w-10 h-10 rounded-full object-cover" />
                  <% else %>
                    <div class="w-10 h-10 bg-blue-500 text-white rounded-full flex items-center justify-center font-medium">
                      <%= if post.bluesky_user && post.bluesky_user.display_name do %>
                        <%= String.upcase(String.first(post.bluesky_user.display_name)) %>
                      <% else %>
                        B
                      <% end %>
                    </div>
                  <% end %>
                  <div>
                    <div class="font-medium text-zinc-900">
                      <%= if post.bluesky_user do %>
                        <%= post.bluesky_user.display_name || post.bluesky_user.handle %>
                      <% else %>
                        Bluesky User
                      <% end %>
                    </div>
                    <%= if post.bluesky_user && post.bluesky_user.handle do %>
                      <div class="text-sm text-zinc-500">@<%= post.bluesky_user.handle %></div>
                    <% end %>
                    <div class="text-sm text-zinc-500">
                      <%= if post.record_created_at do %>
                        <%= Calendar.strftime(post.record_created_at, "%B %d, %Y at %I:%M %p") %>
                      <% else %>
                        <%= Calendar.strftime(post.inserted_at, "%B %d, %Y at %I:%M %p") %>
                      <% end %>
                    </div>
                  </div>
                </div>
                <div class="text-xs text-zinc-400 font-mono">
                  <%= String.slice(post.cid, 0, 8) %>...
                </div>
              </div>

              <%= if post.record_text do %>
                <div class="text-zinc-900 leading-relaxed mb-4">
                  <%= post.record_text %>
                </div>
              <% end %>

              <%= if post.embed_type do %>
                <div class="mb-4">
                  <%= case post.embed_type do %>
                    <% "external" -> %>
                      <div class="border border-zinc-200 rounded-xl overflow-hidden">
                        <%= if post.embed_thumb do %>
                          <img src={post.embed_thumb} alt={post.embed_title || "Embedded content"} class="w-full h-48 object-cover" />
                        <% end %>
                        <div class="p-4">
                          <%= if post.embed_title do %>
                            <h3 class="font-semibold text-zinc-900 mb-2">
                              <%= if post.embed_uri do %>
                                <a href={post.embed_uri} target="_blank" class="hover:text-blue-600">
                                  <%= post.embed_title %>
                                </a>
                              <% else %>
                                <%= post.embed_title %>
                              <% end %>
                            </h3>
                          <% end %>
                          <%= if post.embed_description do %>
                            <p class="text-zinc-600 text-sm mb-2"><%= post.embed_description %></p>
                          <% end %>
                          <%= if post.embed_uri do %>
                            <a href={post.embed_uri} target="_blank" class="text-blue-600 hover:text-blue-800 text-sm">
                              <%= URI.parse(post.embed_uri).host || post.embed_uri %>
                            </a>
                          <% end %>
                        </div>
                      </div>
                    <% "images" -> %>
                      <%= if post.embed_uri do %>
                        <div class="border border-zinc-200 rounded-xl overflow-hidden">
                          <img src={post.embed_uri} alt={post.embed_title || "Embedded image"} class="w-full h-auto" />
                          <%= if post.embed_title do %>
                            <div class="p-3 bg-zinc-50 text-sm text-zinc-600">
                              <%= post.embed_title %>
                            </div>
                          <% end %>
                        </div>
                      <% end %>
                    <% "video" -> %>
                      <div class="border border-zinc-200 rounded-xl overflow-hidden">
                        <%= if post.embed_thumb do %>
                          <div class="relative">
                            <img src={post.embed_thumb} alt={post.embed_title || "Video thumbnail"} class="w-full h-48 object-cover" />
                            <div class="absolute inset-0 flex items-center justify-center">
                              <div class="bg-black bg-opacity-50 rounded-full p-3">
                                <svg class="w-8 h-8 text-white" fill="currentColor" viewBox="0 0 20 20">
                                  <path d="M8 5v10l8-5-8-5z"/>
                                </svg>
                              </div>
                            </div>
                          </div>
                        <% end %>
                        <%= if post.embed_title do %>
                          <div class="p-3 bg-zinc-50 text-sm text-zinc-600">
                            <%= post.embed_title %>
                          </div>
                        <% end %>
                      </div>
                  <% end %>
                </div>
              <% end %>

              <div class="flex items-center justify-between pt-4 border-t border-zinc-100">
                <div class="flex items-center space-x-4 text-sm text-zinc-500">
                  <%= if post.record_langs do %>
                    <span>Languages: <%= Enum.join(post.record_langs, ", ") %></span>
                  <% end %>
                  <span>Collection: <%= post.collection %></span>
                  <span>Operation: <%= post.operation %></span>
                </div>
                <a 
                  href={"https://bsky.app/profile/#{post.rkey}"} 
                  target="_blank" 
                  class="text-blue-600 hover:text-blue-800 text-sm font-medium"
                >
                  View on Bluesky →
                </a>
              </div>
            </div>
          <% end %>

          <%= if @bluesky_posts == [] do %>
            <div class="bg-white rounded-2xl p-12 shadow-sm border border-zinc-200 text-center">
              <div class="text-zinc-500 text-lg mb-4">
                No Nathan Fielder skeets found yet.
              </div>
              <p class="text-zinc-400">
                We're monitoring Bluesky for mentions of Nathan Fielder. Check back soon!
              </p>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end