defmodule RaffApp.RaffleParticipant do
  use RaffApp.SingleWriterProcess

  def participate(raffle_id, user_id) do
    GenServer.call(process_name(raffle_id), {:participate, user_id, DateTime.utc_now()})
  end

  def draw_winner(raffle_id) do
    GenServer.call(process_name(raffle_id), :draw_winner)
  end

  def get_winner(raffle_id) do
    GenServer.call(process_name(raffle_id), :get_winner)
  end

  def get_status(raffle_id) do
    GenServer.call(process_name(raffle_id), :get_status)
  end

  def handle_participate(
        user_id,
        now \\ DateTime.utc_now(),
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

  def handle_draw_winner(_from, %{participants: participants, winner: nil} = state) do
    case map_size(participants) do
      0 ->
        {:reply, {:error, :no_participants}, state}

      participant_count ->
        # Algoritmo Fisher-Yates shuffle para ser justo
        winner_user_id = select_winner(participants)

        # Atualiza estado
        new_state = %{state | winner: winner_user_id, status: :finished}

        # Backup em ETS
        :ets.insert(:raffle_backup, {
          state.raffle_id,
          winner_user_id,
          participant_count,
          DateTime.utc_now()
        })

        {:reply, {:ok, winner_user_id}, new_state}
    end
  end

  def handle_draw_winner(_from, %{winner: winner} = state) when not is_nil(winner) do
    {:reply, {:ok, winner}, state}
  end

  def handle_draw_winner(_from, %{status: status} = state) when status != :open do
    {:reply, {:error, :raffle_not_open}, state}
  end

  def handle_get_winner(_from, %{winner: winner} = state) do
    {:reply, winner, state}
  end

  def handle_get_status(
        _from,
        %{status: status, process_data: draw_date, participants: participants} = state
      ) do
    status_info = %{
      status: status,
      draw_date: draw_date,
      participant_count: map_size(participants),
      is_expired: DateTime.compare(DateTime.utc_now(), draw_date) != :lt
    }

    {:reply, status_info, state}
  end

  defp select_winner(participants) do
    participants
    |> Map.values()
    |> Enum.shuffle()
    |> hd()
    |> Map.get(:user_id)
  end
end
