# Kraken Cryptocurrency Prices

A real-time cryptocurrency price viewer for the Kraken exchange, built with Elixir, Phoenix, and LiveView.

## Features

- Real-time price updates via WebSocket connection to Kraken
- Displays comprehensive trading information:
  - Last trade price with 24h change percentage
  - Best ask and bid prices
  - 24h high and low prices
  - Trading volume
  - Price history (last 3 updates)
- Paginated view of trading pairs (12 pairs per page)
- Modern, responsive UI with Tailwind CSS
- Docker support for easy deployment
- Live price updates with color-coded price changes
- Timezone-aware timestamps (Europe/Kyiv)

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

1. Build the Docker image and Run the container:
```bash
docker-compose up -d
```

Visit [`localhost:4000`](http://localhost:4000) in your browser.

## Architecture

The application consists of several key components:

- `KrakenPrices.Application`: Main application supervisor that manages all processes
- `KrakenPrices.Kraken.WebSocket`: Handles WebSocket connection to Kraken
- `KrakenPricesWeb.PageLive`: Main LiveView module for real-time price updates and UI
- `KrakenPrices.PubSub`: Manages real-time price updates distribution
- `KrakenPricesWeb.Telemetry`: Handles application metrics and monitoring

The application uses Phoenix LiveView for real-time updates without writing custom JavaScript. The UI is built with Tailwind CSS for a modern, responsive design.

## Development

The project includes several development tools:

- Credo for code consistency
- Formatter for consistent code style
- LiveDashboard for monitoring (available in development)
- Swoosh for email preview in development
