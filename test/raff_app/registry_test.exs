defmodule RaffApp.RegistryTest do
  use ExUnit.Case

  test "registry is working" do
    assert Process.whereis(RaffApp.ParticipantRegistry) != nil

    raffle_id = 999
    draw_date = DateTime.add(DateTime.utc_now(), 3600)

    {:ok, pid} = RaffApp.RaffleParticipant.start_link(raffle_id, draw_date)

    assert Registry.lookup(RaffApp.ParticipantRegistry, raffle_id) == [{pid, nil}]

    assert :ok = RaffApp.RaffleParticipant.participate(raffle_id, 1)
  end
end
