defmodule RaffApp.RaffleManager do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(
      __MODULE__,
      %{data: %{}, next_id: 1},
      Keyword.merge(opts, name: __MODULE__)
    )
  end

  def create_raffle(name, draw_date) do
    GenServer.call(__MODULE__, {:create_raffle, name, draw_date})
  end

  def find(id) do
    GenServer.call(__MODULE__, {:find, id})
  end

  def list do
    GenServer.call(__MODULE__, :list)
  end

  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  def init(state) do
    {:ok, state}
  end

  def handle_call(
        {:create_raffle, name, draw_date},
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

    # Agenda sorteio automático (se o scheduler existir)
    if Process.whereis(RaffApp.RaffleScheduler) do
      RaffApp.RaffleScheduler.schedule_raffle_draw(id, draw_date)
    end

    {:reply, {:ok, raffle}, new_state}
  end

  def handle_call({:find, id}, _from, %{data: data} = state) do
    raffle = Map.get(data, id)

    if raffle do
      {:reply, {:ok, raffle}, state}
    else
      {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call(:list, _from, %{data: data} = state) do
    raffles = Map.values(data)
    {:reply, raffles, state}
  end

  def handle_call(:clear, _from, _state) do
    initial_state = %{data: %{}, next_id: 1}
    {:reply, :ok, initial_state}
  end
end
