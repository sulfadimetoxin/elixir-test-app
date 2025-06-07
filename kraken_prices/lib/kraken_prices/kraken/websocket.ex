defmodule KrakenPrices.Kraken.WebSocket do
  use WebSockex
  require Logger

  alias KrakenPrices.PubSub

  @ws_url "wss://ws.kraken.com/v2"
  @max_retries 5
  # 1 second
  @initial_backoff 1000
  # 30 seconds
  @heartbeat_interval 30_000
  @batch_size 20

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    Logger.info("Starting WebSocket connection to #{@ws_url}")

    case WebSockex.start_link(
           @ws_url,
           __MODULE__,
           %{
             pairs: [],
             subscribed: false,
             name: name,
             retry_count: 0,
             last_heartbeat: DateTime.utc_now(),
             pending_pairs: []
           },
           name: name
         ) do
      {:ok, pid} ->
        Logger.info("WebSocket connection established")
        # Start a separate process to handle subscriptions
        spawn(fn ->
          Process.sleep(1000)
          send(pid, :subscribe)
        end)

        # Start heartbeat process
        spawn(fn ->
          Process.sleep(@heartbeat_interval)
          send(pid, :heartbeat)
        end)

        {:ok, pid}

      {:error, reason} ->
        Logger.error("Failed to start WebSocket: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl WebSockex
  def handle_connect(_conn, state) do
    Logger.info("Connected to Kraken WebSocket")
    {:ok, state}
  end

  @impl WebSockex
  def handle_frame({:text, msg}, state) do
    case Jason.decode(msg) do
      {:ok, data} ->
        handle_message(data, state)

      {:error, error} ->
        Logger.error("Failed to decode message: #{inspect(error)}")
        {:ok, state}
    end
  end

  @impl WebSockex
  def handle_info(:subscribe, state) do
    # Send subscription message through a separate process
    spawn(fn ->
      subscribe_msg = %{
        "method" => "subscribe",
        "params" => %{
          "channel" => "instrument"
        }
      }

      Logger.info("Sending instrument subscription: #{inspect(subscribe_msg)}")
      WebSockex.send_frame(state.name, {:text, Jason.encode!(subscribe_msg)})
    end)

    {:ok, state}
  end

  @impl WebSockex
  def handle_info(:subscribe_next_batch, state) do
    case state.pending_pairs do
      [] ->
        {:ok, state}

      pairs ->
        {batch, remaining} = Enum.split(pairs, @batch_size)
        Logger.info("Subscribing to next batch of #{length(batch)} pairs")

        spawn(fn ->
          subscribe_msg = %{
            "method" => "subscribe",
            "params" => %{
              "channel" => "ticker",
              "symbol" => batch
            }
          }

          Logger.info("Sending ticker subscription for batch: #{inspect(batch)}")
          WebSockex.send_frame(state.name, {:text, Jason.encode!(subscribe_msg)})
        end)

        maybe_schedule_next_batch(remaining, state.name)
        {:ok, %{state | pending_pairs: remaining}}
    end
  end

  @impl WebSockex
  def handle_info(:heartbeat, state) do
    # Send ping message
    spawn(fn ->
      ping_msg = %{
        "method" => "ping"
      }

      Logger.debug("Sending heartbeat ping")
      WebSockex.send_frame(state.name, {:text, Jason.encode!(ping_msg)})
    end)

    # Schedule next heartbeat
    spawn(fn ->
      Process.sleep(@heartbeat_interval)
      send(state.name, :heartbeat)
    end)

    {:ok, %{state | last_heartbeat: DateTime.utc_now()}}
  end

  defp maybe_schedule_next_batch([], _name), do: :ok

  defp maybe_schedule_next_batch(_remaining, name) do
    spawn(fn ->
      Process.sleep(1000)
      send(name, :subscribe_next_batch)
    end)
  end

  @impl WebSockex
  def handle_cast({:send, msg}, state) do
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  @impl WebSockex
  def handle_disconnect(%{reason: {:local, reason}}, state) do
    Logger.info("Local disconnect: #{inspect(reason)}")
    {:ok, state}
  end

  @impl WebSockex
  def handle_disconnect(%{reason: {:remote, 429}}, state) do
    retry_count = state.retry_count + 1

    if retry_count <= @max_retries do
      backoff = (@initial_backoff * :math.pow(2, retry_count - 1)) |> round()

      Logger.warning(
        "Rate limited. Retrying in #{backoff}ms (attempt #{retry_count}/#{@max_retries})"
      )

      Process.sleep(backoff)
      {:reconnect, %{state | retry_count: retry_count}}
    else
      Logger.error("Max retries reached. Giving up.")
      {:ok, state}
    end
  end

  @impl WebSockex
  def handle_disconnect(%{reason: {:remote, :closed}} = _disconnect_map, state) do
    Logger.warning("Connection closed by server. Attempting to reconnect...")
    # Wait a bit before reconnecting
    Process.sleep(1000)
    {:reconnect, state}
  end

  @impl WebSockex
  def handle_disconnect(disconnect_map, state) do
    Logger.warning("Disconnected from Kraken WebSocket: #{inspect(disconnect_map)}")
    # Wait a bit before reconnecting
    Process.sleep(1000)
    {:reconnect, state}
  end

  @impl WebSockex
  def terminate(reason, _state) do
    Logger.warning("WebSocket terminating: #{inspect(reason)}")
    :ok
  end

  defp handle_message(
         %{"method" => "subscribe", "success" => true, "result" => %{"channel" => "instrument"}} =
           _msg,
         state
       ) do
    # Logger.info("Successfully subscribed to instrument channel: #{inspect(msg)}")
    {:ok, state}
  end

  defp handle_message(
         %{"method" => "subscribe", "success" => true, "result" => %{"channel" => "ticker"}} =
           _msg,
         state
       ) do
    # Logger.info("Successfully subscribed to ticker channel: #{inspect(msg)}")
    {:ok, state}
  end

  defp handle_message(%{"method" => "pong"}, state) do
    Logger.debug("Received pong response")
    {:ok, state}
  end

  defp handle_message(%{"channel" => "instrument", "data" => data}, state) do
    # Logger.info("Received instrument data: #{inspect(data)}")
    # Extract trading pairs from instruments
    pairs =
      data
      |> Map.fetch!("pairs")
      |> Enum.map(& &1["symbol"])

    # Logger.info("Found #{length(pairs)} pairs for subscription")

    # Start batch subscription process
    spawn(fn ->
      # Wait a bit before starting subscriptions
      Process.sleep(1000)
      send(state.name, :subscribe_next_batch)
    end)

    {:ok, %{state | pairs: pairs, subscribed: true, pending_pairs: pairs}}
  end

  defp handle_message(%{"channel" => "ticker", "data" => data}, state) do
    # Logger.info("Received ticker data: #{inspect(data)}")
    # Process ticker data and broadcast updates
    data
    |> Enum.each(fn ticker ->
      price_info = %{
        last: ticker["last"],
        volume: ticker["volume"],
        high: ticker["high"],
        low: ticker["low"],
        ask: ticker["ask"],
        bid: ticker["bid"],
        change: ticker["change"],
        change_pct: ticker["change_pct"]
      }

      # Logger.info("Broadcasting price update for #{ticker["symbol"]}: #{inspect(price_info)}")
      PubSub.broadcast(
        "price_updates",
        {:price_update, {ticker["symbol"], price_info, DateTime.utc_now()}}
      )
    end)

    {:ok, state}
  end

  defp handle_message(%{"error" => error}, state) do
    Logger.error("Received error from Kraken: #{inspect(error)}")
    {:ok, state}
  end

  defp handle_message(
         %{
           "method" => "subscribe",
           "result" => %{"channelID" => channel_id, "channelName" => "ticker", "pair" => pair}
         },
         state
       ) do
    Logger.info("Successfully subscribed to ticker for #{pair} on channel #{channel_id}")
    PubSub.broadcast("price_updates", {:price_update, {pair, %{}, DateTime.utc_now()}})
    {:ok, state}
  end

  defp handle_message(msg, state) do
    Logger.debug("Received unhandled message: #{inspect(msg)}")
    {:ok, state}
  end
end
