defmodule RaffApp.UserRegistryTest do
  use ExUnit.Case, async: false

  alias RaffApp.UserRegistry

  setup do
    UserRegistry.clear()
    :ok
  end

  describe "register/2 and get/1" do
    test "registra um usuário e encontra pelo ID" do
      user_id = 1
      user = %{id: user_id, email: "test@example.com", name: "Test User"}

      assert {:ok, registered_user} = UserRegistry.register(user_id, user)
      assert registered_user.email == "test@example.com"

      found_user = UserRegistry.get(user_id)
      assert found_user.email == "test@example.com"
    end

    test "retorna nil para usuário não encontrado" do
      assert nil == UserRegistry.get(999)
    end

    test "sobrescreve usuário existente com mesmo ID" do
      user_id = 1
      user1 = %{id: user_id, email: "old@example.com", name: "Old User"}
      user2 = %{id: user_id, email: "new@example.com", name: "New User"}

      assert {:ok, _} = UserRegistry.register(user_id, user1)
      assert {:ok, _} = UserRegistry.register(user_id, user2)

      found_user = UserRegistry.get(user_id)
      assert found_user.email == "new@example.com"
    end
  end

  describe "find_by_email/1" do
    test "encontra usuário pelo email" do
      user1 = %{id: 1, email: "user1@example.com", name: "User One"}
      user2 = %{id: 2, email: "user2@example.com", name: "User Two"}

      assert {:ok, _} = UserRegistry.register(1, user1)
      assert {:ok, _} = UserRegistry.register(2, user2)

      found_user1 = UserRegistry.find_by_email("user1@example.com")
      assert found_user1.id == 1

      found_user2 = UserRegistry.find_by_email("user2@example.com")
      assert found_user2.id == 2
    end

    test "retorna nil quando email não existe" do
      user = %{id: 1, email: "exists@example.com", name: "Test"}
      assert {:ok, _} = UserRegistry.register(1, user)

      assert nil == UserRegistry.find_by_email("nonexistent@example.com")
    end

    test "funciona com emails case insensitive" do
      user = %{id: 1, email: "Test@Example.COM", name: "Test"}
      assert {:ok, _} = UserRegistry.register(1, user)

      # Deve encontrar independente do case
      found_user = UserRegistry.find_by_email("test@example.com")
      assert found_user.email == "test@example.com"

      found_user2 = UserRegistry.find_by_email("TEST@EXAMPLE.COM")
      assert found_user2.email == "test@example.com"
    end
  end

  describe "list/0" do
    test "retorna lista de todos os usuários" do
      user1 = %{id: 1, email: "user1@example.com", name: "User One"}
      user2 = %{id: 2, email: "user2@example.com", name: "User Two"}

      assert {:ok, _} = UserRegistry.register(1, user1)
      assert {:ok, _} = UserRegistry.register(2, user2)

      users = UserRegistry.list()

      assert length(users) == 2
      assert Enum.any?(users, fn u -> u.id == 1 end)
      assert Enum.any?(users, fn u -> u.id == 2 end)
    end

    test "retorna lista vazia quando não há usuários" do
      assert [] == UserRegistry.list()
    end
  end

  describe "concorrência" do
    test "múltiplos processos podem registrar usuários simultaneamente" do
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            user = %{id: i, email: "user#{i}@example.com", name: "User #{i}"}
            UserRegistry.register(i, user)
          end)
        end

      results = Task.await_many(tasks)
      assert Enum.all?(results, &match?({:ok, _}, &1))

      users = UserRegistry.list()
      assert length(users) == 10
    end

    test "busca concorrente por email não causa race conditions" do
      user = %{id: 1, email: "test@example.com", name: "Test"}
      assert {:ok, _} = UserRegistry.register(1, user)

      tasks =
        for _ <- 1..20 do
          Task.async(fn ->
            UserRegistry.find_by_email("test@example.com")
          end)
        end

      results = Task.await_many(tasks)
      assert Enum.all?(results, &(&1 != nil))
      assert Enum.any?(results, &(&1.email == "test@example.com"))
    end
  end

  describe "edge cases" do
    test "lida com emails duplicados (primeiro registro é retornado)" do
      user1 = %{id: 1, email: "duplicate@example.com", name: "First"}
      user2 = %{id: 2, email: "duplicate@example.com", name: "Second"}

      assert {:ok, _} = UserRegistry.register(1, user1)
      assert {:ok, _} = UserRegistry.register(2, user2)

      found_user = UserRegistry.find_by_email("duplicate@example.com")
      assert found_user != nil
      assert found_user.id == 1

      assert UserRegistry.get(1) != nil
      assert UserRegistry.get(2) != nil
    end

    test "lida com usuários sem email" do
      user = %{id: 1, name: "No Email User"}

      assert {:ok, registered_user} = UserRegistry.register(1, user)
      assert registered_user.name == "No Email User"

      assert nil == UserRegistry.find_by_email("any@example.com")
      found_user = UserRegistry.get(1)
      assert found_user.name == "No Email User"
    end

    test "normaliza emails para lowercase no registro" do
      user = %{id: 1, email: "MixedCase@Example.COM", name: "Test"}
      assert {:ok, registered_user} = UserRegistry.register(1, user)

      assert registered_user.email == "mixedcase@example.com"

      # Deve encontrar com qualquer case na busca
      assert UserRegistry.find_by_email("MIXEDCASE@EXAMPLE.COM") != nil
      assert UserRegistry.find_by_email("mixedcase@example.com") != nil
    end
  end
end
