defmodule RaffApp.RaffleParticipantTest do
  use ExUnit.Case, async: true

  setup do
    raffle_id = System.unique_integer([:positive])
    draw_date = DateTime.add(DateTime.utc_now(), 3600)

    {:ok, _pid} = RaffApp.RaffleParticipant.start_link(raffle_id, draw_date)

    %{raffle_id: raffle_id, draw_date: draw_date}
  end

  defp cleanup_raffle(raffle_id) do
    case Registry.lookup(RaffApp.ParticipantRegistry, raffle_id) do
      [{pid, _}] ->
        ref = Process.monitor(pid)
        GenServer.stop(pid)
        assert_receive {:DOWN, ^ref, :process, _object, _reason}

      [] ->
        :ok
    end
  end

  describe "participate/2" do
    test "allows user to participate in open raffle", %{raffle_id: raffle_id} do
      user_id = 1
      assert :ok = RaffApp.RaffleParticipant.participate(raffle_id, user_id)
    end

    test "prevents user from participating twice", %{raffle_id: raffle_id} do
      user_id = 1

      assert :ok = RaffApp.RaffleParticipant.participate(raffle_id, user_id)

      assert {:error, :already_participated} =
               RaffApp.RaffleParticipant.participate(raffle_id, user_id)
    end

    test "allows different users to participate in same raffle", %{raffle_id: raffle_id} do
      user_1 = 1
      user_2 = 2

      assert :ok = RaffApp.RaffleParticipant.participate(raffle_id, user_1)
      assert :ok = RaffApp.RaffleParticipant.participate(raffle_id, user_2)
    end
  end

  describe "get_status/1" do
    test "returns participant count in status", %{raffle_id: raffle_id} do
      user_1 = 1
      user_2 = 2

      RaffApp.RaffleParticipant.participate(raffle_id, user_1)
      RaffApp.RaffleParticipant.participate(raffle_id, user_2)

      status = RaffApp.RaffleParticipant.get_status(raffle_id)

      assert status.participant_count == 2
      assert status.status == :open
    end

    test "returns zero participants for new raffle", %{raffle_id: raffle_id} do
      status = RaffApp.RaffleParticipant.get_status(raffle_id)

      assert status.participant_count == 0
      assert status.status == :open
    end
  end

  describe "concurrent participation" do
    test "many users can join concurrently without race conditions", %{raffle_id: raffle_id} do
      tasks =
        for id <- 1..50 do
          Task.async(fn ->
            RaffApp.RaffleParticipant.participate(raffle_id, id)
          end)
        end

      results = Task.await_many(tasks)
      assert Enum.count(results) == 50
      assert Enum.all?(results, fn r -> r == :ok end)

      participants = RaffApp.RaffleParticipant.get_participants(raffle_id)
      assert length(participants) == 50
    end

    test "same user concurrently only joins once", %{raffle_id: raffle_id} do
      tasks =
        for _ <- 1..30 do
          Task.async(fn ->
            RaffApp.RaffleParticipant.participate(raffle_id, 999)
          end)
        end

      results = Task.await_many(tasks)

      assert Enum.count(Enum.filter(results, &(&1 == :ok))) == 1
      assert Enum.count(Enum.filter(results, &(&1 == {:error, :already_participated}))) == 29

      participants = RaffApp.RaffleParticipant.get_participants(raffle_id)
      assert length(participants) == 1
    end
  end

  describe "expired raffle" do
    test "prevents participation in expired raffle" do
      raffle_id = System.unique_integer([:positive])
      past_date = DateTime.add(DateTime.utc_now(), -3600)

      {:ok, _pid} = RaffApp.RaffleParticipant.start_link(raffle_id, past_date)

      assert {:error, :raffle_expired} = RaffApp.RaffleParticipant.participate(raffle_id, 1)
    end
  end
end
