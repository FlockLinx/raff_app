defmodule RaffleApp.RaffleManager do
  use RaffleApp.SimpleRegistry, name: __MODULE__

  def create_raffle(name, draw_date) do
    register(name, draw_date)
  end

  def handle_register_default(
        {:register, name, draw_date},
        _from,
        %{data: data, next_id: next_id} = state
      ) do
    id = next_id

    raffle = %{
      id: id,
      name: name,
      draw_date: draw_date,
      status: :open,
      created_at: DateTime.utc_now()
    }

    new_data = Map.put(data, id, raffle)
    new_state = %{state | data: new_data, next_id: next_id + 1}
    {:reply, {:ok, raffle}, new_state}
  end
end
