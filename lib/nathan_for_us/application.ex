defmodule NathanForUs.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      NathanForUsWeb.Telemetry,
      NathanForUs.Repo,
      {DNSCluster, query: Application.get_env(:nathan_for_us, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: NathanForUs.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: NathanForUs.Finch},
      # Start a worker by calling: NathanForUs.Worker.start_link(arg)
      # {NathanForUs.Worker, arg},
      # Start to serve requests, typically the last entry
      NathanForUsWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: NathanForUs.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    NathanForUsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
