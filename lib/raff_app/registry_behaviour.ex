defmodule RaffleApp.RegistryBehaviour do
  @callback register(name :: String.t(), email :: String.t()) :: {:ok, map()} | {:error, term()}
  @callback get(id :: integer()) :: map() | nil
  @callback list() :: [map()]
end
