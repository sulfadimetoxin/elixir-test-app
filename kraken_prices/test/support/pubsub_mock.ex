defmodule KrakenPrices.PubSubMock do
  # Define the behavior for PubSub
  defmodule Behaviour do
    @callback subscribe(atom(), String.t()) :: :ok
    @callback broadcast(atom(), String.t(), any()) :: :ok
  end

  # Define the mock module for PubSub
  Mox.defmock(Mock, for: Behaviour)
end
