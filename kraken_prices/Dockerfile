FROM elixir:1.15.8

# Install Node.js and npm
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get update \
    && apt-get install -y nodejs \
    && npm install -g npm@latest

RUN mkdir /app
WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy only the files needed for dependency installation
COPY mix.exs mix.lock ./
RUN mix deps.get

# Install and build assets
COPY assets/package.json ./assets/
RUN cd assets && npm install

# Copy the rest of the application
COPY . .

# Ensure asset directories exist
RUN mkdir -p assets/js assets/css assets/vendor priv/static/assets

# Compile dependencies and build assets
RUN mix deps.compile
RUN mix assets.setup
RUN mix assets.build

# Set default environment variables
ENV SECRET_KEY_BASE="zbBHEQpUthm8eti6nr+hGrPPY0/nkDNMn68S2v62GRCsf2wGqi6zQ5uqL3FbWaWl"
ENV PHX_SERVER=true

CMD ["mix", "phx.server"]