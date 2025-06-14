defmodule KrakenPrices.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      KrakenPricesWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: KrakenPrices.PubSub},
      # Start the Endpoint (http/https)
      KrakenPricesWeb.Endpoint,
      # Start the WebSocket client
      KrakenPrices.Kraken.WebSocket
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: KrakenPrices.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    KrakenPricesWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
