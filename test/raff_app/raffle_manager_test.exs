defmodule RaffApp.RaffleManagerTest do
  use ExUnit.Case, async: false

  alias RaffApp.RaffleManager

  setup do
    GenServer.call(RaffleManager, :clear)
    :ok
  end

  describe "create_raffle/2" do
    test "cria um novo raffle com dados válidos" do
      name = "Grand Prize Raffle"
      # 1 hora no futuro
      draw_date = DateTime.add(DateTime.utc_now(), 3600)

      assert {:ok, raffle} = RaffleManager.create_raffle(name, draw_date)

      assert raffle.id == 1
      assert raffle.name == name
      assert raffle.draw_date == draw_date
      assert raffle.status == :open
      assert %DateTime{} = raffle.created_at
    end

    test "incrementa IDs automaticamente para múltiplos raffles" do
      draw_date = DateTime.add(DateTime.utc_now(), 3600)

      assert {:ok, raffle1} = RaffleManager.create_raffle("First", draw_date)
      assert {:ok, raffle2} = RaffleManager.create_raffle("Second", draw_date)
      assert {:ok, raffle3} = RaffleManager.create_raffle("Third", draw_date)

      assert raffle1.id == 1
      assert raffle2.id == 2
      assert raffle3.id == 3
    end

    test "cria raffles com mesma data de sorteio" do
      # 2 horas no futuro
      draw_date = DateTime.add(DateTime.utc_now(), 7200)

      assert {:ok, raffle1} = RaffleManager.create_raffle("Raffle A", draw_date)
      assert {:ok, raffle2} = RaffleManager.create_raffle("Raffle B", draw_date)

      assert raffle1.draw_date == draw_date
      assert raffle2.draw_date == draw_date
    end
  end

  describe "find/1" do
    test "encontra raffle pelo ID" do
      name = "Findable Raffle"
      draw_date = DateTime.add(DateTime.utc_now(), 3600)

      assert {:ok, created_raffle} = RaffleManager.create_raffle(name, draw_date)
      assert {:ok, found_raffle} = RaffleManager.find(created_raffle.id)

      assert found_raffle == created_raffle
    end

    test "retorna error para raffle não encontrado" do
      assert {:error, :not_found} = RaffleManager.find(999)
    end
  end

  describe "list/0" do
    test "lista todos os raffles criados" do
      draw_date = DateTime.add(DateTime.utc_now(), 3600)

      assert {:ok, raffle1} = RaffleManager.create_raffle("First", draw_date)
      assert {:ok, raffle2} = RaffleManager.create_raffle("Second", draw_date)

      raffles = RaffleManager.list()

      assert length(raffles) == 2
      assert Enum.member?(raffles, raffle1)
      assert Enum.member?(raffles, raffle2)
    end

    test "retorna lista vazia quando não há raffles" do
      assert [] == RaffleManager.list()
    end
  end

  describe "concorrência" do
    test "cria múltiplos raffles concorrentemente sem race conditions" do
      draw_date = DateTime.add(DateTime.utc_now(), 3600)

      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            RaffleManager.create_raffle("Raffle #{i}", draw_date)
          end)
        end

      results = Task.await_many(tasks)

      assert Enum.all?(results, &match?({:ok, _}, &1))

      raffles = RaffleManager.list()
      ids = Enum.map(raffles, & &1.id) |> Enum.sort()
      assert ids == Enum.to_list(1..10)
    end

    test "busca concorrente de raffles funciona corretamente" do
      draw_date = DateTime.add(DateTime.utc_now(), 3600)
      assert {:ok, raffle} = RaffleManager.create_raffle("Concurrent", draw_date)

      tasks =
        for _ <- 1..15 do
          Task.async(fn ->
            RaffleManager.find(raffle.id)
          end)
        end

      results = Task.await_many(tasks)
      assert Enum.all?(results, &(&1 == {:ok, raffle}))
    end
  end

  describe "edge cases e validações" do
    test "expired raffle" do
      past_date = DateTime.add(DateTime.utc_now(), -3600)
      assert {:ok, raffle} = RaffleManager.create_raffle("Past Raffle", past_date)

      assert raffle.status == :open
    end

    test "duplicated names" do
      draw_date = DateTime.add(DateTime.utc_now(), 3600)
      name = "Duplicate Name"

      assert {:ok, raffle1} = RaffleManager.create_raffle(name, draw_date)
      assert {:ok, raffle2} = RaffleManager.create_raffle(name, draw_date)

      assert raffle1.name == raffle2.name
      assert raffle1.id != raffle2.id
    end

    test "long names" do
      long_name = String.duplicate("A", 1000)
      draw_date = DateTime.add(DateTime.utc_now(), 3600)

      assert {:ok, raffle} = RaffleManager.create_raffle(long_name, draw_date)
      assert raffle.name == long_name
    end
  end

  describe "integrated with RaffleParticipant" do
    test "raffle created can have participant" do
      draw_date = DateTime.add(DateTime.utc_now(), 3600)

      assert {:ok, raffle} = RaffleManager.create_raffle("Integration Test", draw_date)
      assert {:ok, _pid} = RaffApp.RaffleParticipant.start_link(raffle.id, draw_date)
      assert :ok = RaffApp.RaffleParticipant.participate(raffle.id, 1)
    end
  end
end
