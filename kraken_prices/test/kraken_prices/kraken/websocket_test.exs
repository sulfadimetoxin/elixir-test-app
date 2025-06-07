defmodule KrakenPrices.Kraken.WebSocketTest do
  use ExUnit.Case, async: true

  import Mox

  alias KrakenPrices.PubSubMock

  setup :verify_on_exit!

  setup do
    # Set up the mock
    Mox.stub_with(PubSubMock, KrakenPrices.PubSub)
    :ok
  end

  test "start_link returns ok tuple and schedules subscription" do
    assert {:ok, pid} = KrakenPrices.Kraken.WebSocket.start_link(name: :test_websocket)
    assert Process.alive?(pid)
  end

  test "handle_connect returns ok with state" do
    assert {:ok, state} = KrakenPrices.Kraken.WebSocket.handle_connect(%{}, %{subscribed: false})
    assert state.subscribed == false
  end

  test "handle_frame handles subscribe success for instrument channel" do
    success_msg = Jason.encode!(%{
      "method" => "subscribe",
      "success" => true,
      "result" => %{"channel" => "instrument"}
    })
    assert {:ok, state} = KrakenPrices.Kraken.WebSocket.handle_frame({:text, success_msg}, %{subscribed: false})
    assert state.subscribed == false
  end

  test "handle_frame handles subscribe success for ticker channel" do
    success_msg = Jason.encode!(%{
      "method" => "subscribe",
      "success" => true,
      "result" => %{"channel" => "ticker"}
    })
    assert {:ok, state} = KrakenPrices.Kraken.WebSocket.handle_frame({:text, success_msg}, %{subscribed: false})
    assert state.subscribed == false
  end

  test "handle_frame handles pong" do
    pong_msg = Jason.encode!(%{"method" => "pong"})
    assert {:ok, state} = KrakenPrices.Kraken.WebSocket.handle_frame({:text, pong_msg}, %{subscribed: false})
    assert state.subscribed == false
  end

  test "handle_frame handles instrument data" do
    instrument_data = %{
      "channel" => "instrument",
      "data" => %{
        "pairs" => [
          %{"symbol" => "XETHUSD"},
          %{"symbol" => "XXBTUSD"}
        ]
      }
    }
    state = %{
      subscribed: false,
      pending_pairs: [],
      pairs: [],
      name: self()  # Use the test process as the name
    }
    assert {:ok, new_state} = KrakenPrices.Kraken.WebSocket.handle_frame({:text, Jason.encode!(instrument_data)}, state)
    assert new_state.pending_pairs == ["XETHUSD", "XXBTUSD"]
    assert new_state.pairs == ["XETHUSD", "XXBTUSD"]
    assert new_state.subscribed == true
  end

  test "handle_frame handles ticker data" do
    ticker_data = %{
      "channel" => "ticker",
      "data" => [
        %{
          "symbol" => "XETHUSD",
          "last" => "2000.00",
          "ask" => "2001.00",
          "bid" => "1999.00",
          "high" => "2100.00",
          "low" => "1900.00",
          "volume" => "1000.00",
          "change" => "50.00",
          "change_pct" => "2.5"
        }
      ]
    }
    assert {:ok, state} = KrakenPrices.Kraken.WebSocket.handle_frame({:text, Jason.encode!(ticker_data)}, %{subscribed: false})
    assert state.subscribed == false
  end

  test "handle_frame handles error" do
    error_msg = Jason.encode!(%{"error" => "Invalid subscription"})
    assert {:ok, state} = KrakenPrices.Kraken.WebSocket.handle_frame({:text, error_msg}, %{subscribed: false})
    assert state.subscribed == false
  end

  test "handle_info(:subscribe) sends instrument subscription" do
    assert {:ok, state} = KrakenPrices.Kraken.WebSocket.handle_info(:subscribe, %{subscribed: false, name: :test_websocket})
    assert state.subscribed == false
  end

  test "handle_info(:subscribe_next_batch) with empty pending pairs" do
    assert {:ok, state} = KrakenPrices.Kraken.WebSocket.handle_info(:subscribe_next_batch, %{subscribed: false, pending_pairs: []})
    assert state.pending_pairs == []
  end

  test "handle_info(:subscribe_next_batch) with pending pairs" do
    pairs = Enum.map(1..25, &"PAIR#{&1}")
    state = %{
      subscribed: false,
      pending_pairs: pairs,
      name: self()  # Use the test process as the name
    }
    assert {:ok, new_state} = KrakenPrices.Kraken.WebSocket.handle_info(:subscribe_next_batch, state)
    assert length(new_state.pending_pairs) == 5  # 25 - 20 (batch_size)
  end

  test "handle_info(:heartbeat) sends ping" do
    state = %{
      subscribed: false,
      name: :test_websocket,
      last_heartbeat: DateTime.utc_now()
    }
    assert {:ok, new_state} = KrakenPrices.Kraken.WebSocket.handle_info(:heartbeat, state)
    assert new_state.subscribed == false
    assert DateTime.compare(new_state.last_heartbeat, state.last_heartbeat) == :gt
  end

  test "handle_disconnect with local reason" do
    assert {:ok, state} = KrakenPrices.Kraken.WebSocket.handle_disconnect(%{reason: {:local, :normal}}, %{subscribed: false})
    assert state.subscribed == false
  end

  test "handle_disconnect with rate limit" do
    assert {:reconnect, state} = KrakenPrices.Kraken.WebSocket.handle_disconnect(%{reason: {:remote, 429}}, %{subscribed: false, retry_count: 0})
    assert state.retry_count == 1
  end

  test "handle_disconnect with remote closed" do
    assert {:reconnect, state} = KrakenPrices.Kraken.WebSocket.handle_disconnect(%{reason: {:remote, :closed}}, %{subscribed: false})
    assert state.subscribed == false
  end

  test "handle_disconnect with other reason" do
    assert {:reconnect, state} = KrakenPrices.Kraken.WebSocket.handle_disconnect(%{reason: :unknown}, %{subscribed: false})
    assert state.subscribed == false
  end

  test "terminate logs warning" do
    assert :ok = KrakenPrices.Kraken.WebSocket.terminate(:normal, %{subscribed: false})
  end
end
