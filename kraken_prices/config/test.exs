import Config

# Configure the endpoint for testing
config :kraken_prices, KrakenPricesWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :kraken_prices, KrakenPricesWeb.Endpoint,
  secret_key_base: "28ST9sEhLAW7BsLu3JrXiUsHPILcCdOAACtG3F8kKZCCtz1YfnuGJ3aHmZUMUJ6+",
  server: false

# In test we don't send emails
config :kraken_prices, KrakenPrices.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
