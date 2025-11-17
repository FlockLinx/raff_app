defmodule RaffleApp.UserRegistry do
  use RaffleApp.SimpleRegistry, name: __MODULE__

  def find_by_email(email) do
    GenServer.call(__MODULE__, {:find_by_email, email})
  end

  def handle_call_custom({:find_by_email, email}, _from, %{data: data} = state) do
    user =
      Enum.find_value(data, fn {_id, user} ->
        if user.email == email, do: user
      end)

    {:reply, user, state}
  end
end
