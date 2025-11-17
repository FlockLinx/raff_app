defmodule RaffApp.RaffleParticipant do
  use RaffApp.SingleWriterProcess

  def handle_participate(
        user_id,
        now,
        _from,
        %{process_data: draw_date, participants: participants, participant_ids: ids} = state
      ) do
    cond do
      DateTime.compare(now, draw_date) != :lt ->
        {:reply, {:error, :raffle_expired}, state}

      MapSet.member?(ids, user_id) ->
        {:reply, {:error, :already_participated}, state}

      true ->
        participant = %{
          user_id: user_id,
          participated_at: now
        }

        new_participants = Map.put(participants, user_id, participant)
        new_ids = MapSet.put(ids, user_id)

        new_state = %{state | participants: new_participants, participant_ids: new_ids}
        {:reply, :ok, new_state}
    end
  end
end
