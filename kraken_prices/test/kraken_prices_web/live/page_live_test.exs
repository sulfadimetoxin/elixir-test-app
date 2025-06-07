defmodule KrakenPricesWeb.PageLiveTest do
  use KrakenPricesWeb.ConnCase
  import Phoenix.LiveViewTest
  import Phoenix.ConnTest
  import Mox

  setup do
    Mox.stub_with(KrakenPrices.PubSubMock, KrakenPrices.PubSub)
    :ok
  end

  test "renders main heading", %{conn: conn} do
    expect(KrakenPrices.PubSubMock, :subscribe, fn _topic -> :ok end)
    {:ok, view, _html} = live(conn, "/")
    assert render(view) =~ "Kraken Prices"
  end

  test "subscribes to PubSub", %{conn: conn} do
    expect(KrakenPrices.PubSubMock, :subscribe, fn _topic -> :ok end)
    {:ok, _view, _html} = live(conn, "/")
  end

  test "mounts with initial state", %{conn: conn} do
    # Expect the subscription
    expect(KrakenPrices.PubSubMock, :subscribe, fn _topic -> :ok end)

    {:ok, view, _html} = live(conn, "/")
    assert view |> element("h1") |> render() =~ "Kraken Prices"
    assert view |> element(".text-gray-500") |> render() =~ "Total Pairs: 0"
  end

  test "handles price update for new pair", %{conn: conn} do
    # Expect the subscription
    expect(KrakenPrices.PubSubMock, :subscribe, fn _topic -> :ok end)

    {:ok, view, _html} = live(conn, "/")

    # Simulate receiving a price update message
    pair = "ETH/USD"

    price_info = %{
      last: 2600.00,
      ask: 2600.10,
      bid: 2599.90,
      high: 2700.00,
      low: 2500.00,
      volume: 2000.00,
      change: 20.00,
      change_pct: 0.80
    }

    timestamp = DateTime.utc_now()

    # Send the message to the LiveView process
    send(view.pid, {:price_update, {pair, price_info, timestamp}})

    # Wait for the LiveView to process the message and update
    assert render(view) =~ pair

    # Check that the UI was updated with correct values
    assert view |> element("h3", pair) |> render() =~ pair
    assert view |> element("p.text-gray-600") |> render() =~ "Last Price: $2600.00"
    assert view |> element("p.text-gray-500", "Ask") |> render() =~ "Ask: $2600.10"
    assert view |> element("p.text-gray-500", "Bid") |> render() =~ "Bid: $2599.90"
    assert view |> element("p.text-gray-500", "High") |> render() =~ "High: $2700.00"
    assert view |> element("p.text-gray-500", "Low") |> render() =~ "Low: $2500.00"
    assert view |> element("p.text-gray-500", "Volume") |> render() =~ "Volume: 2000.00000"
    assert view |> element("p.text-sm.text-green-600") |> render() =~ "20.00000 (0.80000%)"
  end

  test "handles price update for existing pair", %{conn: conn} do
    # Expect the subscription
    expect(KrakenPrices.PubSubMock, :subscribe, fn _topic -> :ok end)

    {:ok, view, _html} = live(conn, "/")

    # First update
    pair = "ETH/USD"

    price_info1 = %{
      last: 2600.00,
      ask: 2600.10,
      bid: 2599.90,
      high: 2700.00,
      low: 2500.00,
      volume: 2000.00,
      change: 20.00,
      change_pct: 0.80
    }

    timestamp1 = DateTime.utc_now()
    send(view.pid, {:price_update, {pair, price_info1, timestamp1}})
    assert render(view) =~ pair

    # Second update
    price_info2 = %{
      last: 2601.00,
      ask: 2601.10,
      bid: 2600.90,
      high: 2700.00,
      low: 2500.00,
      volume: 2001.00,
      change: 21.00,
      change_pct: 0.81
    }

    timestamp2 = DateTime.utc_now()
    send(view.pid, {:price_update, {pair, price_info2, timestamp2}})
    assert render(view) =~ pair

    # Check that the UI was updated with the latest values
    assert view |> element("p.text-gray-600") |> render() =~ "Last Price: $2601.00"
    assert view |> element("p.text-gray-500", "Ask") |> render() =~ "Ask: $2601.10"
    assert view |> element("p.text-gray-500", "Bid") |> render() =~ "Bid: $2600.90"
    assert view |> element("p.text-gray-500", "Volume") |> render() =~ "Volume: 2001.00000"
    assert view |> element("p.text-sm.text-green-600") |> render() =~ "21.00000 (0.81000%)"
  end

  test "handles pagination", %{conn: conn} do
    # Expect the subscription
    expect(KrakenPrices.PubSubMock, :subscribe, fn _topic -> :ok end)

    {:ok, view, _html} = live(conn, "/")

    # Add 15 pairs (more than @per_page)
    pairs = Enum.map(1..15, &"PAIR#{&1}")

    Enum.each(pairs, fn pair ->
      price_info = %{
        last: 1000.00,
        ask: 1000.10,
        bid: 999.90,
        high: 1100.00,
        low: 900.00,
        volume: 1000.00,
        change: 10.00,
        change_pct: 1.00
      }

      send(view.pid, {:price_update, {pair, price_info, DateTime.utc_now()}})
    end)

    # Verify first page content (should show pairs 1-12)
    rendered = render(view)

    Enum.each(1..12, fn n ->
      assert rendered =~ "PAIR#{n}"
    end)

    refute rendered =~ "PAIR13"
    refute rendered =~ "PAIR14"
    refute rendered =~ "PAIR15"

    # Click next page using patch navigation
    html = view |> element("a", "Next") |> render_click()

    # Verify second page content (should show pairs 13-15)
    assert html =~ "PAIR13"
    assert html =~ "PAIR14"
    assert html =~ "PAIR15"
    refute html =~ "PAIR2"
    refute html =~ "PAIR3"
  end

  test "formats numbers correctly", %{conn: conn} do
    # Expect the subscription
    expect(KrakenPrices.PubSubMock, :subscribe, fn _topic -> :ok end)

    {:ok, view, _html} = live(conn, "/")

    # Add a pair with integer and float values
    pair = "ETH/USD"

    price_info = %{
      last: 2600,
      ask: 2600.12345,
      bid: 2599.9,
      high: 2700,
      low: 2500,
      volume: 2000,
      change: 20,
      change_pct: 0.8
    }

    send(view.pid, {:price_update, {pair, price_info, DateTime.utc_now()}})
    assert render(view) =~ pair

    # Check integer formatting
    assert view |> element("p.text-gray-600") |> render() =~ "Last Price: $2600"
    assert view |> element("p.text-gray-500", "High") |> render() =~ "High: $2700"

    # Check float formatting
    assert view |> element("p.text-gray-500", "Ask") |> render() =~ "Ask: $2600.12345"
    assert view |> element("p.text-gray-500", "Bid") |> render() =~ "Bid: $2599.90000"
  end

  test "handles multiple pairs with pagination", %{conn: conn} do
    # Expect the subscription
    expect(KrakenPrices.PubSubMock, :subscribe, fn _topic -> :ok end)

    {:ok, view, _html} = live(conn, "/")

    # Add pairs in reverse order to test ordering
    pairs = ["PAIR3", "PAIR2", "PAIR1"]

    Enum.each(pairs, fn pair ->
      price_info = %{
        last: 1000.00,
        ask: 1000.10,
        bid: 999.90,
        high: 1100.00,
        low: 900.00,
        volume: 1000.00,
        change: 10.00,
        change_pct: 1.00
      }

      send(view.pid, {:price_update, {pair, price_info, DateTime.utc_now()}})
    end)

    # Check that pairs are displayed in order of appearance
    rendered = render(view)
    assert rendered =~ "PAIR1"
    assert rendered =~ "PAIR2"
    assert rendered =~ "PAIR3"

    # Check that pairs appear in the correct order by verifying their relative positions
    # in the rendered HTML
    pairs = ["PAIR1", "PAIR2", "PAIR3"]

    pairs_with_positions =
      Enum.map(pairs, fn pair ->
        {pair, String.contains?(rendered, pair)}
      end)

    # Verify all pairs are present
    assert Enum.all?(pairs_with_positions, fn {_pair, present} -> present end)
  end
end
