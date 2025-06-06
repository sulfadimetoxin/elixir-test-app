defmodule KrakenPricesWeb.PriceLive.Index do
  use KrakenPricesWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(KrakenPrices.PubSub, "kraken_prices")
    end

    {:ok, assign(socket, prices: %{})}
  end

  @impl true
  def handle_info({:price_update, {pair, price_info}}, socket) do
    prices = Map.put(socket.assigns.prices, pair, price_info)
    {:noreply, assign(socket, prices: prices)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <h1 class="text-3xl font-bold mb-8">Kraken Cryptocurrency Prices</h1>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <%= for {pair, price} <- @prices do %>
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-xl font-semibold mb-4">{pair}</h2>
            <div class="space-y-2">
              <div class="flex justify-between">
                <span class="text-gray-600">Best Ask:</span>
                <span class="font-medium">{price["a"] |> List.first()}</span>
              </div>
              <div class="flex justify-between">
                <span class="text-gray-600">Best Bid:</span>
                <span class="font-medium">{price["b"] |> List.first()}</span>
              </div>
              <div class="flex justify-between">
                <span class="text-gray-600">Last Trade:</span>
                <span class="font-medium">{price["c"] |> List.first()}</span>
              </div>
              <div class="flex justify-between">
                <span class="text-gray-600">Volume:</span>
                <span class="font-medium">{price["v"] |> List.first()}</span>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
