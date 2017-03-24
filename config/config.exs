# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# config :logger, :console,
#   level: :debug,
#   format: "$date $time $metadata[$level] $message\n",
#   metadata: [:module]
config :logger, backends: []

config :gentry,
  retries: 5,
  retry_backoff: 100