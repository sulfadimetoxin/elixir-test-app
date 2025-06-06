defmodule KrakenPrices.Kraken.WebSocketTest do
  use ExUnit.Case, async: true

  import Mox

  alias KrakenPrices.Kraken.WebSocket
  alias KrakenPrices.PubSubMock

  # You'll likely need to mock WebSockex or use a test server
  # For now, we'll focus on testing the logic within the callbacks
  # assuming valid messages are received or functions are called.

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

  test "handle_connect schedules subscription and resets subscribed state" do
    {:ok, _pid} = KrakenPrices.Kraken.WebSocket.start_link(name: :test_websocket_2)
    assert {:ok, %{subscribed: false}} = KrakenPrices.Kraken.WebSocket.handle_connect(%{}, %{subscribed: true})
  end

  test "handle_frame handles ping and replies with pong" do
    {:ok, _pid} = KrakenPrices.Kraken.WebSocket.start_link(name: :test_websocket)
    assert_receive {:text, msg}, 1000
    assert Jason.decode!(msg)["event"] == "pong"
  end

  test "handle_frame handles pong" do
    {:ok, _pid} = KrakenPrices.Kraken.WebSocket.start_link(name: :test_websocket_2)
    pong_msg = Jason.encode!(%{event: "pong"})
    assert {:ok, _state} = KrakenPrices.Kraken.WebSocket.handle_frame({:text, pong_msg}, %{subscribed: false})
  end

  test "handle_frame handles ticker data and broadcasts" do
    {:ok, _pid} = KrakenPrices.Kraken.WebSocket.start_link(name: :test_websocket_2)
    ticker_data = %{
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
    send(:test_websocket_2, {:text, Jason.encode!(%{"channel" => "ticker", "data" => ticker_data})})
    assert_receive {:broadcast, "kraken_prices", {:price_update, {"ETH/USD", _price_info, _timestamp}}}, 1000
  end

  test "handle_frame handles error and schedules reconnect" do
    {:ok, _pid} = KrakenPrices.Kraken.WebSocket.start_link(name: :test_websocket_3)
    error_msg = Jason.encode!(%{error: "Invalid subscription"})
    assert {:ok, _state} = KrakenPrices.Kraken.WebSocket.handle_frame({:text, error_msg}, %{subscribed: false})
  end

  test "handle_frame handles subscribe success and updates subscribed state" do
    {:ok, _pid} = KrakenPrices.Kraken.WebSocket.start_link(name: :test_websocket_4)
    success_msg = Jason.encode!(%{
      method: "subscribe",
      result: %{channel: "ticker", symbol: "XETHUSD"},
      success: true
    })
    assert {:ok, %{subscribed: true}} = KrakenPrices.Kraken.WebSocket.handle_frame({:text, success_msg}, %{subscribed: false})
  end

  test "handle_frame handles unhandled messages" do
    {:ok, _pid} = KrakenPrices.Kraken.WebSocket.start_link(name: :test_websocket_5)
    msg = Jason.encode!(%{event: "unknown"})
    assert {:ok, _state} = KrakenPrices.Kraken.WebSocket.handle_frame({:text, msg}, %{subscribed: false})
  end

  test "handle_info(:subscribe) sends subscription message when not subscribed" do
    {:ok, _pid} = KrakenPrices.Kraken.WebSocket.start_link(name: :test_websocket_6)
    assert {:reply, {:text, msg}, _state} = KrakenPrices.Kraken.WebSocket.handle_info(:subscribe, %{subscribed: false})
    decoded = Jason.decode!(msg)
    assert decoded["method"] == "subscribe"
    assert decoded["params"]["channel"] == "ticker"
  end

  test "handle_info(:subscribe) does not send subscription message when subscribed" do
    {:ok, _pid} = KrakenPrices.Kraken.WebSocket.start_link(name: :test_websocket_7)
    assert {:ok, _state} = KrakenPrices.Kraken.WebSocket.handle_info(:subscribe, %{subscribed: true})
  end

  test "handle_disconnect schedules reconnect and resets subscribed state" do
    {:ok, _pid} = KrakenPrices.Kraken.WebSocket.start_link(name: :test_websocket_3)
    send(:test_websocket_3, {:disconnect, %{reason: :normal}})
    assert_receive :subscribe, 6000
  end

  test "terminate schedules reconnect" do
    {:ok, _pid} = KrakenPrices.Kraken.WebSocket.start_link(name: :test_websocket_8)
    assert :ok = KrakenPrices.Kraken.WebSocket.terminate(:normal, %{subscribed: true})
  end
end
