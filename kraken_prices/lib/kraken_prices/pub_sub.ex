defmodule KrakenPrices.PubSub do
  @moduledoc """
  PubSub module for handling price updates.
  """

  @behaviour KrakenPrices.PubSubBehaviour

  @impl true
  def subscribe(topic) do
    Phoenix.PubSub.subscribe(KrakenPrices.PubSub, topic)
  end

  @impl true
  def broadcast(topic, message) do
    Phoenix.PubSub.broadcast(KrakenPrices.PubSub, topic, message)
  end
end
