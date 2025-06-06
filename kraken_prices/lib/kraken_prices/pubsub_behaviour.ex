defmodule KrakenPrices.PubSubBehaviour do
  @callback subscribe(atom(), String.t()) :: :ok
  @callback broadcast(atom(), String.t(), any()) :: :ok
end
