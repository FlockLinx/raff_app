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

    start_raffle_participant(id, draw_date)

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

  defp start_raffle_participant(raffle_id, draw_date) do
    case Process.whereis(RaffApp.RaffleParticipantSupervisor) do
      pid when is_pid(pid) ->
        case RaffApp.RaffleParticipantSupervisor.start_raffle_participant(raffle_id, draw_date) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          _ -> start_directly(raffle_id, draw_date)
        end

      _ ->
        start_directly(raffle_id, draw_date)
    end
  end

  defp start_directly(raffle_id, draw_date) do
    case RaffApp.RaffleParticipant.start_link(raffle_id, draw_date) do
      {:ok, _pid} ->
        :ok

      {:error, {:already_started, _pid}} ->
        :ok

      _ ->
        :error
    end
  end
end
