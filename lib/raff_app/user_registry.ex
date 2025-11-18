defmodule RaffApp.UserRegistry do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, Keyword.merge(opts, name: __MODULE__))
  end

  def register(id, user) do
    normalized_user =
      if Map.has_key?(user, :email) do
        %{user | email: String.downcase(user.email)}
      else
        user
      end

    GenServer.call(__MODULE__, {:register, id, normalized_user})
  end

  def get(id) do
    GenServer.call(__MODULE__, {:get, id})
  end

  def find_by_email(email) do
    GenServer.call(__MODULE__, {:find_by_email, String.downcase(email)})
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

  def handle_call({:register, id, user}, _from, state) do
    new_state = Map.put(state, id, user)
    {:reply, {:ok, user}, new_state}
  end

  def handle_call({:get, id}, _from, state) do
    user = Map.get(state, id)
    {:reply, user, state}
  end

  def handle_call({:find_by_email, email}, _from, state) do
    user =
      Enum.find_value(state, fn {_id, user} ->
        if Map.get(user, :email) == email, do: user
      end)

    {:reply, user, state}
  end

  def handle_call(:list, _from, state) do
    users = Map.values(state)
    {:reply, users, state}
  end

  def handle_call(:clear, _from, _state) do
    {:reply, :ok, %{}}
  end
end
