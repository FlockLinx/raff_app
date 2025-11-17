defmodule RaffApp.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      RaffleApp.UserRegistry,
      RaffleApp.RaffleManager
    ]

    opts = [strategy: :one_for_one, name: RaffApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
