defmodule KrakenPrices.PubSubBehaviour do
  @moduledoc """
  Behaviour for PubSub operations.
  """

  @callback subscribe(topic :: String.t()) :: :ok | {:error, term()}
  @callback broadcast(topic :: String.t(), message :: term()) :: :ok | {:error, term()}
end
