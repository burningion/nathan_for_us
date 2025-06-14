defmodule NathanForUsWeb.StayTunedLive do
  use NathanForUsWeb, :live_view

  on_mount {NathanForUsWeb.UserAuth, :ensure_authenticated}

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.flash_group flash={@flash} />
    <div class="min-h-screen bg-zinc-50 flex items-center justify-center px-4">
      <div class="w-full max-w-2xl">
        <div class="bg-white rounded-3xl shadow-xl p-12 border border-zinc-200">
          <div class="text-center mb-8">
            <img
              src={~p"/images/fellow-pilot.png"}
              alt="Nathan For Us"
              class="mx-auto w-24 h-24 object-cover rounded-2xl shadow-lg mb-8"
            />

            <h1 class="text-4xl font-bold text-zinc-900 mb-4">
              Welcome aboard!
            </h1>
            <div class="bg-zinc-50 rounded-2xl p-8 border border-zinc-200">
              <h2 class="text-2xl font-semibold text-zinc-900 mb-4">Stay tuned</h2>
              <p class="text-zinc-600 text-lg">
                We'll notify you at
                <span class="font-semibold text-zinc-900">{@current_user.email}</span>
                when we're ready to launch.
              </p>
            </div>
          </div>

          <div class="text-center">
            <.link
              href={~p"/users/log_out"}
              method="delete"
              class="inline-flex items-center px-6 py-3 text-sm font-semibold text-zinc-700 bg-white border border-zinc-300 rounded-xl hover:bg-zinc-50 transition-colors"
            >
              Log out
            </.link>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
