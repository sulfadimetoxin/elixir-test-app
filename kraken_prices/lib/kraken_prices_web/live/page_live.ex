defmodule KrakenPricesWeb.PageLive do
  use KrakenPricesWeb, :live_view
  require Logger

  alias KrakenPrices.PubSub

  # 4 rows of 3 cards
  @per_page 12
  # Number of page links to show around current page
  @page_range 5

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      PubSub.subscribe("price_updates")
    end

    {:ok,
     assign(socket,
       prices: %{},
       price_history: %{},
       pairs_order: [],
       pairs_set: MapSet.new(),
       page: 1,
       pairs: []
     )}
  end

  @impl true
  def handle_info({:price_update, {pair, price_info, timestamp}}, socket) do
    # Update current prices
    prices = Map.put(socket.assigns.prices, pair, price_info)

    # Update price history (keep last 3 updates)
    price_history = socket.assigns.price_history
    history = [%{price: price_info, timestamp: timestamp} | price_history[pair] || []]
    history = Enum.take(history, 3)
    price_history = Map.put(price_history, pair, history)

    # Update pairs order if this is a new pair
    {pairs_order, pairs_set} =
      if MapSet.member?(socket.assigns.pairs_set, pair) do
        Logger.debug("Received update for existing pair: #{pair}")
        {socket.assigns.pairs_order, socket.assigns.pairs_set}
      else
        Logger.info("Adding new pair: #{pair}")

        {Enum.concat(socket.assigns.pairs_order, [pair]),
         MapSet.put(socket.assigns.pairs_set, pair)}
      end

    {:noreply,
     assign(socket,
       prices: prices,
       price_history: price_history,
       pairs_order: pairs_order,
       pairs_set: pairs_set
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    page = (params["page"] || "1") |> String.to_integer()
    {:noreply, assign(socket, page: page)}
  end

  defp paginate_pairs(pairs_order, page) do
    total_pages = ceil(length(pairs_order) / @per_page)
    page = min(max(1, page), total_pages)
    start_idx = (page - 1) * @per_page
    pairs_order |> Enum.slice(start_idx, @per_page)
  end

  defp get_page_numbers(current_page, total_pages) do
    half_range = div(@page_range, 2)
    start_page = max(1, current_page - half_range)
    end_page = min(total_pages, start_page + @page_range - 1)
    start_page = max(1, end_page - @page_range + 1)
    Enum.to_list(start_page..end_page)
  end

  defp format_number(number) when is_integer(number), do: Integer.to_string(number)

  defp format_number(number) when is_float(number),
    do: :erlang.float_to_binary(number, decimals: 5)

  @impl true
  def render(assigns) do
    total_pages = ceil(length(assigns.pairs_order) / @per_page)
    current_page = min(max(1, assigns.page), total_pages)
    page_numbers = get_page_numbers(current_page, total_pages)
    pairs = paginate_pairs(assigns.pairs_order, current_page)

    assigns = assign(assigns, :pairs, pairs)
    assigns = assign(assigns, :total_pages, total_pages)
    assigns = assign(assigns, :page_numbers, page_numbers)
    assigns = assign(assigns, :page, current_page)

    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="flex justify-between items-center mb-8">
        <h1 class="text-3xl font-bold">Kraken Prices</h1>
        <div class="text-sm text-gray-500">
          Total Pairs: {length(@pairs_order)}
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mb-8">
        <%= for pair <- @pairs do %>
          <% price_info = @prices[pair] %>
          <div class="bg-white shadow rounded-lg p-4 hover:shadow-lg transition-shadow duration-200">
            <div class="flex justify-between items-start">
              <div>
                <h3 class="text-lg font-semibold">{pair}</h3>
                <p class="text-gray-600">Last Price: ${format_number(price_info.last)}</p>
              </div>
              <div class="text-right">
                <p class={"text-sm #{if price_info.change >= 0, do: "text-green-600", else: "text-red-600"}"}>
                  {format_number(price_info.change)} ({format_number(price_info.change_pct)}%)
                </p>
              </div>
            </div>
            <div class="mt-2 grid grid-cols-2 gap-2">
              <div>
                <p class="text-sm text-gray-500">Ask: ${format_number(price_info.ask)}</p>
                <p class="text-sm text-gray-500">Bid: ${format_number(price_info.bid)}</p>
              </div>
              <div>
                <p class="text-sm text-gray-500">High: ${format_number(price_info.high)}</p>
                <p class="text-sm text-gray-500">Low: ${format_number(price_info.low)}</p>
              </div>
            </div>
            <div class="mt-2">
              <p class="text-sm text-gray-500">Volume: {format_number(price_info.volume)}</p>
            </div>

            <%= if @price_history[pair] && @price_history[pair] != [] do %>
              <div class="mt-4 border-t pt-4">
                <h4 class="text-sm font-medium text-gray-500 mb-2">Last 3 Prices</h4>
                <div class="space-y-2">
                  <%= for %{price: price_info, timestamp: timestamp} <- @price_history[pair] do %>
                    <div class="flex justify-between text-sm">
                      <span class="text-gray-600">${format_number(price_info.last)}</span>
                      <span class="text-gray-400">
                        {Calendar.strftime(DateTime.shift_zone!(timestamp, "Europe/Kyiv"), "%H:%M:%S")}
                      </span>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>

      <%= if @total_pages > 1 do %>
        <div class="flex justify-center items-center space-x-2">
          <%= if @page > 1 do %>
            <.link
              patch={~p"/?page=#{@page - 1}"}
              class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
            >
              Previous
            </.link>
          <% end %>

          <%= if @page > @page_numbers |> List.first() do %>
            <.link
              patch={~p"/?page=1"}
              class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
            >
              1
            </.link>
            <%= if @page > (@page_numbers |> List.first()) + 1 do %>
              <span class="px-2 text-gray-500">...</span>
            <% end %>
          <% end %>

          <%= for page <- @page_numbers do %>
            <.link
              patch={~p"/?page=#{page}"}
              class={"px-4 py-2 text-sm font-medium rounded-md #{if page == @page, do: "bg-blue-600 text-white", else: "text-gray-700 bg-white border border-gray-300 hover:bg-gray-50"}"}
            >
              {page}
            </.link>
          <% end %>

          <%= if @page < @total_pages - (@page_numbers |> List.last()) + 1 do %>
            <%= if @page < @total_pages - (@page_numbers |> List.last()) do %>
              <span class="px-2 text-gray-500">...</span>
            <% end %>
            <.link
              patch={~p"/?page=#{@total_pages}"}
              class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
            >
              {@total_pages}
            </.link>
          <% end %>

          <%= if @page < @total_pages do %>
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
