# Kraken Cryptocurrency Prices

A real-time cryptocurrency price viewer for the Kraken exchange, built with Elixir, Phoenix, and LiveView.

## Features

- Real-time price updates via WebSocket connection
- Displays best ask, best bid, last trade, and volume for all trading pairs
- Modern, responsive UI with Tailwind CSS
- Docker support for easy deployment

## Requirements

- Elixir 1.14+
- Erlang 25+
- Node.js 16+ (for asset compilation)
- Docker (optional)

## Running Locally

1. Install dependencies:
```bash
mix deps.get
```

2. Install and build assets:
```bash
mix assets.setup
mix assets.build
```

3. Start the Phoenix server:
```bash
mix phx.server
```

Visit [`localhost:4000`](http://localhost:4000) in your browser.

## Running with Docker

1. Build the Docker image:
```bash
docker build -t kraken_prices .
```

2. Run the container:
```bash
docker run -p 4000:4000 kraken_prices
```

Visit [`localhost:4000`](http://localhost:4000) in your browser.

## Architecture

The application consists of several key components:

- `KrakenPrices.Kraken.WebSocket`: Handles WebSocket connection to Kraken
- `KrakenPrices.Kraken.API`: Manages REST API calls to fetch trading pairs
- `KrakenPricesWeb.PriceLive.Index`: LiveView module for real-time price updates

## License

MIT

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
