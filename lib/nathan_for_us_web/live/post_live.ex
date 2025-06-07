defmodule NathanForUsWeb.PostLive do
  use NathanForUsWeb, :live_view

  alias NathanForUs.Social

  @impl true
  def mount(_params, _session, socket) do
    changeset = Social.change_post(%Social.Post{})

    {:ok,
     socket
     |> assign(:changeset, changeset)
     |> assign(:page_title, "Create Post")
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
    if Map.has_key?(socket.assigns, :current_user) && socket.assigns.current_user do
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
           |> put_flash(:info, "Post created successfully.")
           |> push_navigate(to: ~p"/")}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, changeset: changeset)}
      end
    else
      {:noreply, socket}
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
    <div style="max-width: 600px; margin: 0 auto;">
      <div class="business-card">
        <div class="business-card-header">
          <h1 style="font-size: 1.8rem; font-weight: 600; color: var(--nathan-navy); margin: 0; text-align: center;">
            Create Post
          </h1>
        </div>
        
        <div class="business-card-body">
          <.form :let={f} for={@changeset} phx-change="validate" phx-submit="save" class="business-form" id="post-form">
            <div style="margin-bottom: 1.5rem;">
              <.input
                field={f[:content]}
                type="textarea"
                placeholder="What's on your mind?"
                class="business-input business-textarea"
                style="font-size: 1rem; line-height: 1.5; min-height: 120px;"
              />
            </div>

            <div style="margin-bottom: 1.5rem;">
              <label style="display: block; font-weight: 500; color: var(--nathan-navy); margin-bottom: 0.5rem;">
                Add Image (Optional)
              </label>
              <div style="border: 2px dashed #cbd5e0; border-radius: 8px; padding: 1.5rem; text-align: center; background: #f8fafc;">
                <.live_file_input upload={@uploads.image} style="display: none;" />
                <button
                  type="button"
                  phx-click={JS.dispatch("click", to: "##{@uploads.image.ref}")}
                  class="business-btn business-btn--secondary"
                  style="margin-bottom: 0.5rem;"
                >
                  Choose File
                </button>
                <p style="color: var(--nathan-gray); font-size: 0.85rem;">
                  JPG, PNG, GIF up to 5MB
                </p>
              </div>

              <%= for entry <- @uploads.image.entries do %>
                <div style="margin-top: 1rem; padding: 0.75rem; background: white; border: 1px solid #e2e8f0; border-radius: 6px; display: flex; align-items: center; justify-content: space-between;">
                  <span style="color: var(--nathan-navy);"><%= entry.client_name %></span>
                  <button
                    type="button"
                    phx-click="cancel-upload"
                    phx-value-ref={entry.ref}
                    class="business-btn business-btn--danger"
                    style="padding: 0.25rem 0.5rem; font-size: 0.8rem;"
                  >
                    Remove
                  </button>
                </div>
              <% end %>
            </div>

            <div style="display: flex; gap: 1rem;">
              <button
                type="submit"
                disabled={!@changeset.valid?}
                class="business-btn business-btn--primary"
                style="flex: 1; padding: 0.75rem;"
              >
                Post
              </button>
              <.link
                navigate={~p"/"}
                class="business-btn business-btn--secondary"
                style="flex: 1; padding: 0.75rem; text-align: center; text-decoration: none;"
              >
                Cancel
              </.link>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end
end