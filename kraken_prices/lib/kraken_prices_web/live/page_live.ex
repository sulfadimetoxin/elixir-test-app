defmodule KrakenPricesWeb.PageLive do
  use KrakenPricesWeb, :live_view
  require Logger

  @per_page 12  # 4 rows of 3 cards
  @page_range 5  # Number of page links to show around current page

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      KrakenPrices.PubSub.subscribe(KrakenPrices.PubSub, "kraken_prices")
    end

    {:ok, assign(socket, prices: %{}, price_history: %{}, page: 1, pairs_order: [], page_range: @page_range)}
  end

  @impl true
  def handle_info({:price_update, {pair, price_info, timestamp}}, socket) do
    # Update current prices
    prices = Map.put(socket.assigns.prices, pair, price_info)

    # Update price history (keep last 3 updates)
    price_history = socket.assigns.price_history
    history = [%{price: price_info, timestamp: timestamp} | (price_history[pair] || [])]
    history = Enum.take(history, 3)
    price_history = Map.put(price_history, pair, history)

    # Update pairs order if this is a new pair
    pairs_order = if pair in socket.assigns.pairs_order do
      socket.assigns.pairs_order
    else
      socket.assigns.pairs_order ++ [pair]
    end

    {:noreply, assign(socket, prices: prices, price_history: price_history, pairs_order: pairs_order)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    page = (params["page"] || "1") |> String.to_integer()
    {:noreply, assign(socket, page: page)}
  end

  defp paginate_pairs(prices, pairs_order, page) do
    total_pages = ceil(length(pairs_order) / @per_page)
    page = min(max(1, page), total_pages)
    start_idx = (page - 1) * @per_page
    pairs_order |> Enum.slice(start_idx, @per_page)
  end

  defp pagination_range(current_page, total_pages) do
    half_range = div(@page_range, 2)
    start_page = max(1, current_page - half_range)
    end_page = min(total_pages, start_page + @page_range - 1)
    start_page = max(1, end_page - @page_range + 1)
    start_page..end_page
  end

  @impl true
  def render(assigns) do
    pairs = paginate_pairs(assigns.prices, assigns.pairs_order, assigns.page)
    total_pages = ceil(length(assigns.pairs_order) / @per_page)
    page_range = pagination_range(assigns.page, total_pages)

    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="flex justify-between items-center mb-8">
        <h1 class="text-3xl font-bold">Kraken Prices</h1>
        <div class="text-sm text-gray-500">
          Total Pairs: <%= length(@pairs_order) %>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mb-8">
        <%= for pair <- pairs do %>
          <% price_info = @prices[pair] %>
          <div class="bg-white shadow rounded-lg p-4 hover:shadow-lg transition-shadow duration-200">
            <div class="flex justify-between items-start">
              <div>
                <h3 class="text-lg font-semibold"><%= pair %></h3>
                <p class="text-gray-600">Last Price: $<%= :erlang.float_to_binary(price_info.last, decimals: 5) %></p>
              </div>
              <div class="text-right">
                <p class={"text-sm #{if price_info.change >= 0, do: "text-green-600", else: "text-red-600"}"}>
                  <%= :erlang.float_to_binary(price_info.change, decimals: 5) %> (<%= :erlang.float_to_binary(price_info.change_pct, decimals: 2) %>%)
                </p>
              </div>
            </div>
            <div class="mt-2 grid grid-cols-2 gap-2">
              <div>
                <p class="text-sm text-gray-500">Ask: $<%= :erlang.float_to_binary(price_info.ask, decimals: 5) %></p>
                <p class="text-sm text-gray-500">Bid: $<%= :erlang.float_to_binary(price_info.bid, decimals: 5) %></p>
              </div>
              <div>
                <p class="text-sm text-gray-500">High: $<%= :erlang.float_to_binary(price_info.high, decimals: 5) %></p>
                <p class="text-sm text-gray-500">Low: $<%= :erlang.float_to_binary(price_info.low, decimals: 5) %></p>
              </div>
            </div>
            <div class="mt-2">
              <p class="text-sm text-gray-500">Volume: <%= :erlang.float_to_binary(price_info.volume, decimals: 2) %></p>
            </div>

            <%= if @price_history[pair] && @price_history[pair] != [] do %>
              <div class="mt-4 border-t pt-4">
                <h4 class="text-sm font-medium text-gray-500 mb-2">Last 3 Prices</h4>
                <div class="space-y-2">
                  <%= for %{price: price_info, timestamp: timestamp} <- @price_history[pair] do %>
                    <div class="flex justify-between text-sm">
                      <span class="text-gray-600">$<%= :erlang.float_to_binary(price_info.last, decimals: 5) %></span>
                      <span class="text-gray-400"><%= Calendar.strftime(DateTime.shift_zone!(timestamp, "Europe/Kyiv"), "%H:%M:%S") %></span>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>

      <%= if total_pages > 1 do %>
        <div class="flex justify-center items-center space-x-2">
          <%= if @page > 1 do %>
            <.link
              patch={~p"/?page=#{@page - 1}"}
              class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
            >
              Previous
            </.link>
          <% end %>

          <%= if @page > @page_range do %>
            <.link
              patch={~p"/?page=1"}
              class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
            >
              1
            </.link>
            <%= if @page > @page_range + 1 do %>
              <span class="px-2 text-gray-500">...</span>
            <% end %>
          <% end %>

          <%= for page <- page_range do %>
            <.link
              patch={~p"/?page=#{page}"}
              class={"px-4 py-2 text-sm font-medium rounded-md #{if page == @page, do: "bg-blue-600 text-white", else: "text-gray-700 bg-white border border-gray-300 hover:bg-gray-50"}"}
            >
              <%= page %>
            </.link>
          <% end %>

          <%= if @page < total_pages - @page_range + 1 do %>
            <%= if @page < total_pages - @page_range do %>
              <span class="px-2 text-gray-500">...</span>
            <% end %>
            <.link
              patch={~p"/?page=#{total_pages}"}
              class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
            >
              <%= total_pages %>
            </.link>
          <% end %>

          <%= if @page < total_pages do %>
            <.link
              patch={~p"/?page=#{@page + 1}"}
              class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
            >
              Next
            </.link>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
