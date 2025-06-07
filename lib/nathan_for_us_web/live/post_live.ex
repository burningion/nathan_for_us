defmodule NathanForUsWeb.PostLive do
  use NathanForUsWeb, :live_view

  alias NathanForUs.Social

  @impl true
  def mount(_params, _session, socket) do
    changeset = Social.change_post(%Social.Post{})

    {:ok,
     socket
     |> assign(:changeset, changeset)
     |> assign(:page_title, "Share Your Business Wisdom")
     |> allow_upload(:image,
       accept: ~w(.jpg .jpeg .png .gif),
       max_entries: 1,
       max_file_size: 5_000_000
     )}
  end

  @impl true
  def handle_event("validate", %{"post" => post_params}, socket) do
    changeset =
      %Social.Post{}
      |> Social.change_post(post_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, changeset: changeset)}
  end

  @impl true
  def handle_event("save", %{"post" => post_params}, socket) do
    image_url = upload_image(socket)
    
    post_params = 
      post_params
      |> Map.put("user_id", socket.assigns.current_user.id)
      |> Map.put("image_url", image_url)

    case Social.create_post(post_params) do
      {:ok, post} ->
        post = NathanForUs.Repo.preload(post, :user)
        Phoenix.PubSub.broadcast(NathanForUs.PubSub, "posts", {:post_created, post})

        {:noreply,
         socket
         |> put_flash(:info, "Post shared successfully! The business world thanks you.")
         |> push_navigate(to: ~p"/")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :image, ref)}
  end

  defp upload_image(socket) do
    consume_uploaded_entries(socket, :image, fn %{path: path}, _entry ->
      filename = "#{System.unique_integer([:positive])}.jpg"
      dest = Path.join(["priv/static/uploads", filename])
      File.mkdir_p!(Path.dirname(dest))
      File.cp!(path, dest)
      {:ok, "/uploads/#{filename}"}
    end)
    |> List.first()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-lg mx-auto p-4">
      <div class="bg-white border-2 border-gray-300 rounded-lg p-6 shadow-lg">
        <h1 class="text-2xl font-bold text-yellow-600 mb-6 text-center">Share Your Business Wisdom</h1>
        
        <.form for={@changeset} phx-change="validate" phx-submit="save" class="space-y-4">
          <div>
            <.input
              field={@changeset[:content]}
              type="textarea"
              placeholder="What brilliant business strategy would you like to share with the professional community?"
              rows="4"
              class="w-full border-2 border-gray-300 rounded p-3 focus:border-yellow-500 focus:ring-0"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">
              📸 Add a Professional Image (Optional)
            </label>
            <div class="border-2 border-dashed border-gray-300 rounded-lg p-6 text-center">
              <.live_file_input upload={@uploads.image} class="hidden" />
              <button
                type="button"
                phx-click={JS.dispatch("click", to: "##{@uploads.image.ref}")}
                class="bg-gray-100 hover:bg-gray-200 text-gray-700 font-medium py-2 px-4 rounded border-2 border-gray-300"
              >
                Choose File
              </button>
              <p class="text-xs text-gray-500 mt-2">JPG, PNG, GIF up to 5MB</p>
            </div>

            <%= for entry <- @uploads.image.entries do %>
              <div class="mt-2 p-2 bg-gray-50 rounded border flex items-center justify-between">
                <span class="text-sm text-gray-700"><%= entry.client_name %></span>
                <button
                  type="button"
                  phx-click="cancel-upload"
                  phx-value-ref={entry.ref}
                  class="text-red-500 hover:text-red-700"
                >
                  ✕
                </button>
              </div>
            <% end %>
          </div>

          <div class="flex space-x-3">
            <button
              type="submit"
              disabled={!@changeset.valid?}
              class="flex-1 bg-yellow-500 hover:bg-yellow-600 disabled:bg-gray-300 text-black font-bold py-3 px-4 rounded border-2 border-black transform hover:translate-y-[-2px] transition-all disabled:transform-none"
            >
              Share Wisdom
            </button>
            <.link
              navigate={~p"/"}
              class="flex-1 bg-gray-200 hover:bg-gray-300 text-gray-700 font-bold py-3 px-4 rounded border-2 border-gray-400 text-center"
            >
              Cancel
            </.link>
          </div>
        </.form>
      </div>
    </div>
    """
  end
end