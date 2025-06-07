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
    <div style="max-width: 600px; margin: 0 auto;">
      <div class="business-card">
        <div class="business-card-header">
          <h1 style="font-size: 2rem; font-weight: 800; color: var(--nathan-navy); margin: 0; text-align: center;">
            🚀 Share Your Business Wisdom
          </h1>
          <p style="margin-top: 0.5rem; color: var(--nathan-navy); text-align: center; font-size: 1.1rem;">
            Enlighten the business community with your strategic insights
          </p>
        </div>
        
        <div class="business-card-body">
          <.form for={@changeset} phx-change="validate" phx-submit="save" class="business-form">
            <div style="margin-bottom: 1.5rem;">
              <label style="display: block; font-weight: 600; color: var(--nathan-navy); margin-bottom: 0.5rem;">
                📝 Your Business Strategy
              </label>
              <.input
                field={@changeset[:content]}
                type="textarea"
                placeholder="Share your revolutionary business approach that will disrupt conventional thinking..."
                class="business-input business-textarea"
                style="font-size: 1.1rem; line-height: 1.6;"
              />
            </div>

            <div style="margin-bottom: 1.5rem;">
              <label style="display: block; font-weight: 600; color: var(--nathan-navy); margin-bottom: 0.5rem;">
                📊 Supporting Visual Evidence (Optional)
              </label>
              <div style="border: 3px dashed var(--nathan-brown); border-radius: 12px; padding: 2rem; text-align: center; background: var(--nathan-beige);">
                <.live_file_input upload={@uploads.image} style="display: none;" />
                <button
                  type="button"
                  phx-click={JS.dispatch("click", to: "##{@uploads.image.ref}")}
                  class="business-btn business-btn--secondary"
                  style="margin-bottom: 1rem;"
                >
                  📁 Select Professional Image
                </button>
                <p style="color: var(--nathan-gray); font-size: 0.9rem; font-family: 'JetBrains Mono', monospace;">
                  JPG, PNG, GIF • Maximum 5MB • Business-appropriate content only
                </p>
              </div>

              <%= for entry <- @uploads.image.entries do %>
                <div style="margin-top: 1rem; padding: 1rem; background: white; border: 2px solid var(--nathan-brown); border-radius: 8px; display: flex; align-items: center; justify-content: space-between;">
                  <span style="color: var(--nathan-navy); font-weight: 500;"><%= entry.client_name %></span>
                  <button
                    type="button"
                    phx-click="cancel-upload"
                    phx-value-ref={entry.ref}
                    class="business-btn business-btn--danger"
                    style="padding: 0.25rem 0.5rem; font-size: 0.8rem;"
                  >
                    ✕ Remove
                  </button>
                </div>
              <% end %>
            </div>

            <div style="display: flex; gap: 1rem; margin-top: 2rem;">
              <button
                type="submit"
                disabled={!@changeset.valid?}
                class="business-btn business-btn--success"
                style="flex: 1; padding: 1rem; font-size: 1.1rem; font-weight: 700;"
              >
                🎯 Publish Business Insight
              </button>
              <.link
                navigate={~p"/"}
                class="business-btn business-btn--secondary"
                style="flex: 1; padding: 1rem; font-size: 1.1rem; text-align: center; text-decoration: none;"
              >
                ↩️ Return to Feed
              </.link>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end
end