defmodule NathanForUsWeb.ChatRoomLive do
  use NathanForUsWeb, :live_view

  alias NathanForUs.Chat

  on_mount {NathanForUsWeb.UserAuth, :mount_current_user}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(NathanForUs.PubSub, "chat_room")
    end

    approved_words = Chat.list_approved_words()

    # 1% chance for regular users to see the rejected messages button (only if logged in)
    show_rejected_button =
      case socket.assigns.current_user do
        nil -> false
        user -> user.is_admin || :rand.uniform(100) == 1
      end

    total_messages = Chat.get_total_message_count()

    socket =
      socket
      |> assign(:pending_words, Chat.list_pending_words())
      |> assign(:chat_messages, Chat.list_chat_messages())
      |> assign(:approved_words, approved_words)
      |> assign(:filtered_approved_words, approved_words)
      |> assign(:word_search, "")
      |> assign(:word_form, to_form(Chat.change_word(%Chat.Word{}, %{})))
      |> assign(:message_form, to_form(Chat.change_chat_message(%Chat.ChatMessage{})))
      |> assign(:show_welcome_dialog, true)
      |> assign(:show_rejected_button, show_rejected_button)
      |> assign(:show_rejected_modal, false)
      |> assign(:rejected_messages, [])
      |> assign(:total_messages, total_messages)
      |> assign(:show_link_feature, total_messages >= 250)

    {:ok, socket}
  end

  @impl true
  def handle_event("close_welcome_dialog", _params, socket) do
    {:noreply, assign(socket, :show_welcome_dialog, false)}
  end

  @impl true
  def handle_event("open_rejected_modal", _params, socket) do
    rejected_messages = Chat.list_rejected_messages()
    socket =
      socket
      |> assign(:show_rejected_modal, true)
      |> assign(:rejected_messages, rejected_messages)
    {:noreply, socket}
  end

  @impl true
  def handle_event("close_rejected_modal", _params, socket) do
    {:noreply, assign(socket, :show_rejected_modal, false)}
  end

  @impl true
  def handle_event("validate_word", %{"word" => word_params}, socket) do
    changeset = Chat.change_word(%Chat.Word{}, word_params)
    {:noreply, assign(socket, :word_form, to_form(changeset, action: :validate))}
  end

  @impl true
  def handle_event("search_approved_words", %{"value" => search_term}, socket) do
    filtered_words =
      if String.trim(search_term) == "" do
        socket.assigns.approved_words
      else
        socket.assigns.approved_words
        |> Enum.filter(&String.contains?(String.downcase(&1), String.downcase(search_term)))
      end

    socket =
      socket
      |> assign(:word_search, search_term)
      |> assign(:filtered_approved_words, filtered_words)

    {:noreply, socket}
  end

  @impl true
  def handle_event("submit_word", %{"word" => %{"text" => text}}, socket) do
    case socket.assigns.current_user do
      nil ->
        socket = put_flash(socket, :error, "You must log in to submit words!")
        {:noreply, socket}

      user ->
        words =
          text
          |> String.trim()
          |> String.replace(~r/[^\w\s']/, " ")
          |> String.split()
          |> Enum.reject(&(&1 == ""))
          |> Enum.map(&String.downcase/1)
          |> Enum.uniq()

        case words do
          [] ->
            socket =
              socket
              |> assign(:word_form, to_form(Chat.change_word(%Chat.Word{}, %{})))
              |> put_flash(:error, "Please enter at least one word!")
            {:noreply, socket}

          words ->
            results = Enum.map(words, &Chat.submit_word(&1, user.id))

            successes = Enum.count(results, fn {status, _} -> status == :ok end)
            errors = Enum.filter(results, fn {status, _} -> status == :error end)

            socket =
              socket
              |> assign(:pending_words, Chat.list_pending_words())
              |> assign(:word_form, to_form(Chat.change_word(%Chat.Word{}, %{})))

            socket =
              cond do
                successes > 0 && Enum.empty?(errors) ->
                  put_flash(socket, :info, "#{successes} word(s) submitted for approval!")

                successes > 0 ->
                  error_messages =
                    errors
                    |> Enum.map(fn {_, reason} -> format_error_message(reason) end)
                    |> Enum.uniq()
                    |> Enum.join(", ")

                  put_flash(socket, :info, "#{successes} word(s) submitted. Some errors: #{error_messages}")

                true ->
                  error_messages =
                    errors
                    |> Enum.map(fn {_, reason} -> format_error_message(reason) end)
                    |> Enum.uniq()
                    |> Enum.join(", ")

                  put_flash(socket, :error, "No words submitted. Errors: #{error_messages}")
              end

            {:noreply, socket}
        end
    end
  end

  @impl true
  def handle_event("approve_word", %{"id" => word_id}, socket) do
    case socket.assigns.current_user do
      nil ->
        socket = put_flash(socket, :error, "You must log in to approve words!")
        {:noreply, socket}

      user ->
        case Chat.approve_word(String.to_integer(word_id), user.id) do
          {:ok, _word} ->
            updated_approved_words = Chat.list_approved_words()

            filtered_words =
              if String.trim(socket.assigns.word_search) == "" do
                updated_approved_words
              else
                updated_approved_words
                |> Enum.filter(&String.contains?(String.downcase(&1), String.downcase(socket.assigns.word_search)))
              end

            socket =
              socket
              |> assign(:pending_words, Chat.list_pending_words())
              |> assign(:approved_words, updated_approved_words)
              |> assign(:filtered_approved_words, filtered_words)
              |> put_flash(:info, "Word approved!")

            {:noreply, socket}

          {:error, :cannot_approve_own_word} ->
            socket = put_flash(socket, :error, "You cannot approve your own word!")
            {:noreply, socket}

          {:error, _} ->
            socket = put_flash(socket, :error, "Failed to approve word!")
            {:noreply, socket}
        end
    end
  end

  @impl true
  def handle_event("deny_word", %{"id" => word_id}, socket) do
    case socket.assigns.current_user do
      nil ->
        socket = put_flash(socket, :error, "You must log in to deny words!")
        {:noreply, socket}

      user ->
        case Chat.deny_word(String.to_integer(word_id), user.id) do
          {:ok, _word} ->
            socket =
              socket
              |> assign(:pending_words, Chat.list_pending_words())
              |> put_flash(:info, "Word denied!")

            {:noreply, socket}

          {:error, :cannot_deny_own_word} ->
            socket = put_flash(socket, :error, "You cannot deny your own word!")
            {:noreply, socket}

          {:error, _} ->
            socket = put_flash(socket, :error, "Failed to deny word!")
            {:noreply, socket}
        end
    end
  end

  @impl true
  def handle_event("send_message", %{"chat_message" => %{"content" => content}}, socket) do
    case socket.assigns.current_user do
      nil ->
        socket = put_flash(socket, :error, "You must log in to send messages!")
        {:noreply, socket}

      user ->
        attrs = %{content: content, user_id: user.id}

        case Chat.create_chat_message(attrs) do
          {:ok, _message, true} ->
            # Valid message - clear form and push clear event
            socket =
              socket
              |> assign(:message_form, to_form(Chat.change_chat_message(%Chat.ChatMessage{})))
              |> push_event("clear_message_form", %{})

            {:noreply, socket}

          {:ok, _message, false} ->
            # Invalid message - saved but not displayed, clear form and push clear event
            socket =
              socket
              |> assign(:message_form, to_form(Chat.change_chat_message(%Chat.ChatMessage{})))
              |> push_event("clear_message_form", %{})
              |> put_flash(:error, "Message saved but contains unapproved words - not displayed in chat!")

            {:noreply, socket}

          {:error, changeset} ->
            socket = assign(socket, :message_form, to_form(changeset))
            {:noreply, socket}
        end
    end
  end

  defp format_error_message(:already_approved), do: "already approved"
  defp format_error_message(:already_pending), do: "already pending"
  defp format_error_message(:banned_forever), do: "banned forever"
  defp format_error_message(_), do: "unknown error"

  @impl true
  def handle_info({:word_submitted, _word}, socket) do
    socket = assign(socket, :pending_words, Chat.list_pending_words())
    {:noreply, socket}
  end

  @impl true
  def handle_info({:word_approved, _word}, socket) do
    updated_approved_words = Chat.list_approved_words()

    filtered_words =
      if String.trim(socket.assigns.word_search) == "" do
        updated_approved_words
      else
        updated_approved_words
        |> Enum.filter(&String.contains?(String.downcase(&1), String.downcase(socket.assigns.word_search)))
      end

    socket =
      socket
      |> assign(:pending_words, Chat.list_pending_words())
      |> assign(:approved_words, updated_approved_words)
      |> assign(:filtered_approved_words, filtered_words)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:word_denied, _word}, socket) do
    socket = assign(socket, :pending_words, Chat.list_pending_words())
    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    messages = [message | socket.assigns.chat_messages]
    new_total = socket.assigns.total_messages + 1

    socket =
      socket
      |> assign(:chat_messages, messages)
      |> assign(:total_messages, new_total)
      |> assign(:show_link_feature, new_total >= 250)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:words_bulk_approved, _count}, socket) do
    updated_approved_words = Chat.list_approved_words()

    filtered_words =
      if String.trim(socket.assigns.word_search) == "" do
        updated_approved_words
      else
        updated_approved_words
        |> Enum.filter(&String.contains?(String.downcase(&1), String.downcase(socket.assigns.word_search)))
      end

    socket =
      socket
      |> assign(:approved_words, updated_approved_words)
      |> assign(:filtered_approved_words, filtered_words)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:messages_revalidated, count}, socket) do
    # Refresh chat messages to include newly validated ones
    updated_messages = Chat.list_chat_messages()

    socket =
      socket
      |> assign(:chat_messages, updated_messages)
      |> put_flash(:info, "#{count} previously rejected message(s) are now valid and added to chat!")

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <!-- Welcome Dialog -->
    <%= if @show_welcome_dialog do %>
      <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" phx-hook="WelcomeDialog" id="welcome-dialog">
        <div class="bg-white rounded-lg shadow-xl max-w-md mx-4 p-6">
          <div class="text-center">
            <h2 class="text-xl font-bold text-gray-900 mb-4">Welcome to Nathan For Us Chat!</h2>
            <div class="text-left space-y-3 text-sm text-gray-700 mb-6">
              <p><strong>In order to keep chat friendly we banned every word by default.</strong></p>
              <p>To submit a word to be campaigned for allowance, type it in the left.</p>
              <p>If another user votes yes, it will become allowed.</p>
              <p>You can see allowed words on the left and search them to compose messages.</p>
              <p class="text-blue-600 font-medium">Please have a nice time chatting with your friends who also enjoy Nathan and we can build this into an expansive, friendly chat room!</p>
            </div>
            <button
              phx-click="close_welcome_dialog"
              class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg font-medium transition-colors"
              phx-hook="WelcomeDialogButton"
              id="welcome-dialog-button"
            >
              Got it, let's chat!
            </button>
          </div>
        </div>
      </div>
    <% end %>

    <div class="flex bg-gray-100 p-4" style="height: calc(100vh - 80px);">
      <!-- Left Panel - Word Voting -->
      <div class="w-1/3 bg-white border-r border-gray-300 flex flex-col h-full rounded-l-lg">
        <!-- Approved Words Widget -->
        <div class="p-3 border-b border-gray-200 flex-shrink-0">
          <h3 class="text-sm font-semibold text-gray-900 mb-2">Approved Words (searchable)</h3>
          <input
            type="text"
            value={@word_search}
            phx-keyup="search_approved_words"
            phx-debounce="300"
            placeholder="Search approved words..."
            class="w-full mb-2 text-xs border border-gray-300 rounded px-2 py-1 focus:outline-none focus:ring-1 focus:ring-blue-500"
            name="search"
          />
          <div class="bg-gray-50 rounded-lg p-2 mb-2 max-h-60 overflow-y-auto">
            <div class="flex flex-wrap gap-1" id="approved-words-container">
              <%= for word <- @filtered_approved_words do %>
                <span
                  id={"approved-word-#{word}"}
                  class="text-gray-700 text-xs px-1 py-0.5 rounded transition-all duration-200 ease-in-out hover:text-gray-900 hover:bg-gray-100"
                  style="animation: fadeIn 0.3s ease-in-out;"
                >
                  <%= word %>
                </span>
              <% end %>
              <%= if Enum.empty?(@filtered_approved_words) do %>
                <span class="text-gray-400 text-xs italic">
                  <%= if @word_search != "", do: "No words match \"#{@word_search}\"", else: "No approved words yet" %>
                </span>
              <% end %>
            </div>

            <style>
              @keyframes fadeIn {
                from { opacity: 0; transform: translateY(-5px); }
                to { opacity: 1; transform: translateY(0); }
              }

              @keyframes fadeOut {
                from { opacity: 1; transform: translateY(0); }
                to { opacity: 0; transform: translateY(-5px); }
              }

              .word-exit {
                animation: fadeOut 0.2s ease-in-out forwards;
              }
            </style>
          </div>
        </div>

        <div class="p-3 border-b border-gray-200 flex-shrink-0">
          <h2 class="text-base font-semibold text-gray-900">Word Approval (please submit more and approve/deny more)</h2>
        </div>

        <!-- Pending Words List -->
        <div class="flex-1 overflow-y-auto p-3 min-h-0">
          <div class="flex flex-wrap gap-2">
            <%= for word <- @pending_words do %>
              <div class="bg-blue-100 border border-blue-200 rounded-full px-3 py-2 text-xs flex items-center space-x-2 group hover:bg-blue-200 transition-colors">
                <div class="flex items-center min-w-0">
                  <span class="font-medium text-blue-900 whitespace-nowrap"><%= word.text %></span>
                  <%= if word.submission_count > 1 do %>
                    <span class="text-blue-500 ml-1">(#<%= word.submission_count %>)</span>
                  <% end %>
                </div>
                <div class="flex space-x-1">
                  <%= if @current_user do %>
                    <button
                      phx-click="approve_word"
                      phx-value-id={word.id}
                      class="bg-white hover:bg-gray-100 text-black border border-gray-300 w-5 h-5 rounded-full text-xs flex items-center justify-center transition-colors"
                      title="Approve word"
                    >
                      ✓
                    </button>
                    <button
                      phx-click="deny_word"
                      phx-value-id={word.id}
                      class="bg-black hover:bg-gray-800 text-white w-5 h-5 rounded-full text-xs flex items-center justify-center transition-colors"
                      title="Deny word"
                    >
                      ✗
                    </button>
                  <% else %>
                    <span class="text-xs text-gray-400 italic">Login to vote</span>
                  <% end %>
                </div>
              </div>
            <% end %>

            <%= if Enum.empty?(@pending_words) do %>
              <p class="text-gray-500 text-center py-4 text-sm w-full">No words pending approval</p>
            <% end %>
          </div>
        </div>

        <!-- Submit Word Form -->
        <div class="p-3 border-t border-gray-200 flex-shrink-0">
          <%= if @current_user do %>
            <.form for={@word_form} phx-submit="submit_word" phx-change="validate_word" class="space-y-2">
              <.input
                field={@word_form[:text]}
                type="text"
                placeholder="Submit words..."
                required
                class="w-full text-sm"
              />
              <.button type="submit" class="w-full text-sm py-2">
                Submit Words
              </.button>
            </.form>
          <% else %>
            <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-3 space-y-2">
              <p class="text-xs text-yellow-800 font-medium">⚠️ Login Required</p>
              <p class="text-xs text-yellow-700">You must log in to submit words for approval.</p>
              <a href="/users/log_in" class="block w-full text-center bg-blue-600 hover:bg-blue-700 text-white text-xs py-2 px-3 rounded transition-colors">
                Log In to Submit Words
              </a>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Right Panel - Chat -->
      <div class="flex-1 flex flex-col h-full bg-white rounded-r-lg">
        <div class="p-3 border-b border-gray-200 bg-white flex-shrink-0">
          <div class="flex justify-between items-start">
            <div>
              <h2 class="text-base font-semibold text-gray-900">Chat Room</h2>
              <%= if @current_user do %>
                <p class="text-sm text-gray-500">Only approved words are allowed</p>
              <% else %>
                <p class="text-sm text-orange-600">📖 Viewing as guest - log in to participate</p>
              <% end %>
            </div>
            <%= if @show_rejected_button do %>
              <button
                phx-click="open_rejected_modal"
                class="text-xs bg-red-100 hover:bg-red-200 text-red-800 px-2 py-1 rounded border border-red-300 transition-colors"
                title="View rejected messages"
              >
                SEE REJECTED MESSAGES
              </button>
            <% end %>
          </div>
        </div>

        <!-- Chat Messages -->
        <div class="flex-1 overflow-y-auto p-3 space-y-2 min-h-0 bg-gray-50">
          <%= for message <- @chat_messages do %>
            <div class="bg-white rounded p-3 border text-sm">
              <div class="flex items-start space-x-2">
                <div class="flex-1 min-w-0">
                  <div class="flex items-center space-x-2">
                    <span class="font-medium text-gray-900"><%= message.user.email %></span>
                    <span class="text-xs text-gray-500">
                      <%= Calendar.strftime(message.inserted_at, "%I:%M %p") %>
                    </span>
                  </div>
                  <p class="text-gray-700 mt-1 break-words">
                    <%= for {word, index} <- message.content |> String.split() |> Enum.with_index() do %>
                      <%= if index > 0, do: " " %><%= if Chat.is_url?(word) do %>
                        <a href={word} target="_blank" class="text-blue-600 hover:text-blue-800 underline">surprise me</a>
                      <% else %>
                        <%= word %>
                      <% end %>
                    <% end %>
                  </p>
                </div>
              </div>
            </div>
          <% end %>

          <%= if Enum.empty?(@chat_messages) do %>
            <div class="text-center py-8">
              <p class="text-gray-500 text-sm">No messages yet. Start the conversation!</p>
            </div>
          <% end %>
        </div>

        <!-- Message Input -->
        <div class="p-3 border-t border-gray-200 bg-white flex-shrink-0">
          <%= if @current_user do %>
            <.form for={@message_form} phx-submit="send_message" class="space-y-2" phx-hook="MessageForm" id="message-form">
              <.input
                field={@message_form[:content]}
                type="textarea"
                placeholder={if @show_link_feature, do: "Type your message (only approved words + links allowed)...", else: "Type your message (only approved words allowed)..."}
                required
                rows="3"
                class="w-full resize-none text-sm"
                id="message-textarea"
              />
              <div class="flex justify-end">
                <.button type="submit" class="px-6 py-2 text-sm">
                  Send Message
                </.button>
              </div>
            </.form>
          <% else %>
            <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 text-center space-y-3">
              <div class="space-y-1">
                <p class="text-sm font-medium text-blue-900">👀 You're viewing the chat as a guest</p>
                <p class="text-xs text-blue-700">You can read all messages, but you need to log in to participate in the conversation.</p>
              </div>
              <div class="space-y-2">
                <a href="/users/log_in" class="block w-full bg-blue-600 hover:bg-blue-700 text-white text-sm py-2 px-4 rounded transition-colors">
                  Log In to Chat
                </a>
                <a href="/users/register" class="block w-full bg-gray-600 hover:bg-gray-700 text-white text-sm py-2 px-4 rounded transition-colors">
                  Create Account
                </a>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>

    <!-- Rejected Messages Modal -->
    <%= if @show_rejected_modal do %>
      <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" phx-click="close_rejected_modal">
        <div class="bg-white rounded-lg shadow-xl max-w-4xl w-full mx-4 max-h-[80vh] flex flex-col" phx-click-away="close_rejected_modal">
          <div class="p-4 border-b border-gray-200 flex justify-between items-center">
            <h2 class="text-xl font-bold text-gray-900">Rejected Messages</h2>
            <button
              phx-click="close_rejected_modal"
              class="text-gray-400 hover:text-gray-600 text-2xl"
            >
              ×
            </button>
          </div>
          <div class="flex-1 overflow-y-auto p-4">
            <%= if Enum.empty?(@rejected_messages) do %>
              <div class="text-center py-8">
                <p class="text-gray-500">No rejected messages yet!</p>
              </div>
            <% else %>
              <div class="space-y-3">
                <%= for message <- @rejected_messages do %>
                  <div class="bg-red-50 border border-red-200 rounded-lg p-3">
                    <div class="flex items-start justify-between">
                      <div class="flex-1">
                        <div class="flex items-center space-x-2 mb-1">
                          <span class="font-medium text-red-900"><%= message.user.email %></span>
                          <span class="text-xs text-red-600">
                            <%= Calendar.strftime(message.inserted_at, "%m/%d/%y %I:%M %p") %>
                          </span>
                        </div>
                        <p class="text-red-800 break-words"><%= message.content %></p>
                      </div>
                      <span class="text-xs bg-red-200 text-red-800 px-2 py-1 rounded-full ml-2">REJECTED</span>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
          <div class="p-4 border-t border-gray-200 text-center">
            <p class="text-xs text-gray-500">
              These messages contain unapproved words and are not visible in the main chat.
            </p>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
end
