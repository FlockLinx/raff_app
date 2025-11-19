defmodule RaffApp.TestHelpers do
  def clear_all_registries do
    GenServer.call(RaffApp.UserRegistry, :clear)
    GenServer.call(RaffApp.RaffleManager, :clear)

    RaffApp.RaffleManager.list()
    |> Enum.each(fn raffle ->
      case Registry.lookup(RaffApp.ParticipantRegistry, raffle.id) do
        [{pid, _}] -> GenServer.stop(pid)
        [] -> :ok
      end
    end)
  end

  def create_expired_raffle_with_participants(raffle_id, draw_date, user_ids) do
    {:ok, pid} = RaffApp.RaffleParticipant.start_link(raffle_id, draw_date)

    state = :sys.get_state(pid)

    participants =
      Enum.reduce(user_ids, %{}, fn user_id, acc ->
        Map.put(acc, user_id, %{
          user_id: user_id,
          participated_at: DateTime.add(draw_date, -3600)
        })
      end)

    participant_ids = MapSet.new(user_ids)

    new_state = %{
      state
      | participants: participants,
        participant_ids: participant_ids
    }

    :sys.replace_state(pid, fn _ -> new_state end)
    {:ok, pid}
  end

  def process_name(raffle_id) do
    {:via, Registry, {RaffApp.ParticipantRegistry, raffle_id}}
  end

  def get_raffle_state(raffle_id) do
    case Registry.lookup(RaffApp.ParticipantRegistry, raffle_id) do
      [{pid, _}] -> :sys.get_state(pid)
      [] -> nil
    end
  end

  def update_raffle_state(raffle_id, update_fn) do
    case Registry.lookup(RaffApp.ParticipantRegistry, raffle_id) do
      [{pid, _}] ->
        :sys.replace_state(pid, update_fn)
        :ok

      [] ->
        {:error, :not_found}
    end
  end
end
