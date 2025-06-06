defmodule KrakenPrices.PubSub do
  @moduledoc """
  PubSub module for handling real-time updates.
  """

  @behaviour KrakenPrices.PubSubBehaviour

  def subscribe(pubsub, topic) do
    Phoenix.PubSub.subscribe(pubsub, topic)
  end

  def broadcast(pubsub, topic, message) do
    Phoenix.PubSub.broadcast(pubsub, topic, message)
  end
end
