use Mix.Config

config :raff_app, RaffApp.Web.Endpoint,
  http: [port: 4000],
  debug_errors: true

import_config "\#{Mix.env()}.exs"
