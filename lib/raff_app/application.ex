defmodule RaffApp.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: RaffApp.ParticipantRegistry},
      RaffApp.RaffleParticipantSupervisor,
      RaffApp.UserRegistry,
      RaffApp.RaffleManager,
      RaffApp.RaffleScheduler,
      {Plug.Cowboy, scheme: :http, plug: RaffApp.Web.Router, options: [port: 4000]}
    ]

    opts = [strategy: :one_for_one, name: RaffApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
