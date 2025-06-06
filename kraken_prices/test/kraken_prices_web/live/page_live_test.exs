defmodule KrakenPricesWeb.PageLiveTest do
  use ExUnit.Case

  import Phoenix.LiveViewTest
  import Mox

  alias KrakenPrices.PubSubMock
  alias KrakenPricesWeb.PageLive

  setup do
    # Set up the mock
    Mox.stub_with(PubSubMock, KrakenPrices.PubSub)

    # Build a connection for tests
    conn = Phoenix.ConnTest.build_conn()
    {:ok, conn: conn}
  end

  test "accesses LiveViewTest functions via alias" do
    # This test is just to check if the alias works and the function is accessible
    assert is_function(LiveViewTest.assert_rendered/1)
  end

  test "displays the main heading", %{conn: conn} do
    {:ok, _view, html} = live_isolated(conn, KrakenPricesWeb.PageLive)
    assert html =~ "Cryptocurrency Prices"
  end

  test "mounts and subscribes to PubSub", %{conn: conn} do
    {:ok, _view, _html} = live_isolated(conn, KrakenPricesWeb.PageLive)
  end

  # test "handles price_update info message", %{conn: conn} do
  #   {:ok, live_view, _html} = live(conn, "/")

  #   # Simulate receiving a price update message
  #   pair = "ETH/USD"
  #   price_info = %{"bid" => "2599.90", last: "2600.00", ask: "2600.10", high: "2700.00", low: "2500.00", volume: "2000.00", change: "20.00", change_pct: "0.80"}
  #   timestamp = DateTime.utc_now()

  #   message = {:price_update, {pair, price_info, timestamp}}

  #   # Send the message to the LiveView process
  #   send(live_view.pid, message)

  #   # Wait for the LiveView to process the message and update
  #   assert_rendered(live_view) # This asserts that render was called

  #   # Check that assigns were updated correctly
  #   assert live_view.assigns.prices[pair] == price_info
  #   assert live_view.assigns.price_history[pair]
  #   assert Enum.count(live_view.assigns.price_history[pair]) <= 3
  #   assert live_view.assigns.price_history[pair] |> hd() |> Map.get(:price) == price_info
  #   assert live_view.assigns.price_history[pair] |> hd() |> Map.get(:timestamp) == timestamp
  # end

  # You can add more tests for rendering different states,
  # handling multiple price updates for the same pair,
  # handling multiple pairs, etc.
end
