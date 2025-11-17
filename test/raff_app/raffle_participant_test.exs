defmodule RaffApp.RaffleParticipantTest do
  use ExUnit.Case, async: true

  setup do
    raffle_id = 123
    draw_date = DateTime.add(DateTime.utc_now(), 3600)

    cleanup_raffle(123)
    cleanup_raffle(456)

    {:ok, _pid} = RaffApp.RaffleParticipant.start_link(raffle_id, draw_date)

    %{raffle_id: raffle_id, draw_date: draw_date}
  end

  defp cleanup_raffle(raffle_id) do
    case Registry.lookup(RaffApp.ParticipantRegistry, raffle_id) do
      [{pid, _}] ->
        GenServer.stop(pid)
        Process.sleep(10)

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

    test "prevents participation in expired raffle" do
      raffle_id = 456
      past_date = DateTime.add(DateTime.utc_now(), -3600)

      cleanup_raffle(raffle_id)

      {:ok, _pid} = RaffApp.RaffleParticipant.start_link(raffle_id, past_date)

      assert {:error, :raffle_expired} = RaffApp.RaffleParticipant.participate(raffle_id, 1)
    end

    test "allows different users to participate in same raffle", %{raffle_id: raffle_id} do
      user_1 = 1
      user_2 = 2

      assert :ok = RaffApp.RaffleParticipant.participate(raffle_id, user_1)
      assert :ok = RaffApp.RaffleParticipant.participate(raffle_id, user_2)
    end
  end

  describe "get_participants/1" do
    test "returns list of participants", %{raffle_id: raffle_id} do
      user_1 = 1
      user_2 = 2

      RaffApp.RaffleParticipant.participate(raffle_id, user_1)
      RaffApp.RaffleParticipant.participate(raffle_id, user_2)

      participants = RaffApp.RaffleParticipant.get_participants(raffle_id)

      assert length(participants) == 2
      assert Enum.any?(participants, fn p -> p.user_id == user_1 end)
      assert Enum.any?(participants, fn p -> p.user_id == user_2 end)
    end

    test "returns empty list for new raffle", %{raffle_id: raffle_id} do
      assert [] == RaffApp.RaffleParticipant.get_participants(raffle_id)
    end
  end
end
