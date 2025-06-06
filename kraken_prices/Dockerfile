FROM hexpm/elixir:1.15.7-erlang-26.2.1-debian-bullseye-20231009 as build

# Install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git curl \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Prepare build dir
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN MIX_ENV=prod mix deps.compile

# Copy config files first
COPY config config

# Build assets
COPY assets assets
RUN cd assets && npm install
RUN MIX_ENV=prod mix assets.deploy

# Build project
COPY priv priv
COPY lib lib
RUN MIX_ENV=prod mix compile

# Build the release
RUN MIX_ENV=prod mix release kraken_prices

# Start a new build stage
FROM debian:bullseye-slim

RUN apt-get update -y && apt-get install -y libstdc++6 openssl libncurses5 locales \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR /app

# Copy the release from the build stage
COPY --from=build /app/_build/prod/rel/kraken_prices ./

# Debug: List contents of the release directory
RUN ls -la /app

# Set environment variables
ENV MIX_ENV=prod
ENV PORT=4000

# Run the Phoenix app
CMD ["bin/kraken_prices", "start"] 