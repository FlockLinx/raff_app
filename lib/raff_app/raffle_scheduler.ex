defmodule RaffApp.RaffleScheduler do
  use GenServer
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def schedule_raffle_draw(raffle_id, draw_date) do
    GenServer.call(__MODULE__, {:schedule_draw, raffle_id, draw_date})
  end

  def init(_opts) do
    :ets.new(:raffle_backup, [:named_table, :public, :duplicate_bag])

    state = %{
      scheduled_draws: %{}
    }

    Process.send_after(self(), :check_pending_draws, 30_000)

    {:ok, state}
  end

  def handle_call({:schedule_draw, raffle_id, draw_date}, _from, state) do
    %{scheduled_draws: scheduled_draws} = state

    new_scheduled_draws = Map.put(scheduled_draws, raffle_id, draw_date)
    new_state = %{state | scheduled_draws: new_scheduled_draws}

    {:reply, :ok, new_state}
  end

  def handle_info(:check_pending_draws, %{scheduled_draws: scheduled_draws} = state) do
    now = DateTime.utc_now()

    expired_raffles =
      scheduled_draws
      |> Enum.filter(fn {_raffle_id, draw_date} ->
        DateTime.compare(now, draw_date) != :lt
      end)
      |> Enum.map(fn {raffle_id, _} -> raffle_id end)

    Enum.each(expired_raffles, fn raffle_id ->
      Task.start(fn ->
        case Registry.lookup(RaffApp.ParticipantRegistry, raffle_id) do
          [{pid, _}] when is_pid(pid) ->
            case RaffApp.RaffleParticipant.draw_winner(raffle_id) do
              {:ok, winner_id} ->
                Logger.info("Automatically drew winner for raffle #{raffle_id}: #{winner_id}")

              {:error, reason} ->
                Logger.warn("Failed to auto-draw raffle #{raffle_id}: #{reason}")
            end

          _ ->
            Logger.warn("RaffleParticipant not found for auto-draw: #{raffle_id}")
        end
      end)
    end)

    new_scheduled_draws = Map.drop(scheduled_draws, expired_raffles)
    new_state = %{state | scheduled_draws: new_scheduled_draws}

    Process.send_after(self(), :check_pending_draws, 30_000)

    {:noreply, new_state}
  end
end
