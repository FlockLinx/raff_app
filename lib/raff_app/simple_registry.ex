# lib/raffle_app/simple_registry.ex
defmodule RaffleApp.SimpleRegistry do
  defmacro __using__(opts) do
    quote do
      use GenServer

      @registry_name unquote(opts)[:name] || __MODULE__

      def start_link(opts \\ []) do
        GenServer.start_link(__MODULE__, opts, name: @registry_name)
      end

      def register(name, email) do
        GenServer.call(@registry_name, {:register, name, email})
      end

      def get(id) do
        GenServer.call(@registry_name, {:get, id})
      end

      def list do
        GenServer.call(@registry_name, :list)
      end

      def init(opts) do
        {:ok, %{data: %{}, next_id: 1}}
      end

      def handle_call(msg, from, state) do
        case msg do
          {:register, _, _} ->
            if function_exported?(__MODULE__, :handle_register, 4) do
              apply(__MODULE__, :handle_register, [msg, from, state])
            else
              handle_register_default(msg, from, state)
            end

          {:get, _} ->
            if function_exported?(__MODULE__, :handle_get, 3) do
              apply(__MODULE__, :handle_get, [msg, from, state])
            else
              handle_get_default(msg, from, state)
            end

          :list ->
            if function_exported?(__MODULE__, :handle_list, 2) do
              apply(__MODULE__, :handle_list, [from, state])
            else
              handle_list_default(from, state)
            end

          custom_msg ->
            if function_exported?(__MODULE__, :handle_call_custom, 3) do
              apply(__MODULE__, :handle_call_custom, [custom_msg, from, state])
            else
              handle_call_custom_default(custom_msg, from, state)
            end
        end
      end

      def handle_register_default(
            {:register, name, email},
            _from,
            %{data: data, next_id: next_id} = state
          ) do
        id = next_id
        record = %{id: id, name: name, email: email, created_at: DateTime.utc_now()}
        new_data = Map.put(data, id, record)
        new_state = %{state | data: new_data, next_id: next_id + 1}
        {:reply, {:ok, record}, new_state}
      end

      def handle_get_default({:get, id}, _from, %{data: data} = state) do
        {:reply, Map.get(data, id), state}
      end

      def handle_list_default(_from, %{data: data} = state) do
        {:reply, Map.values(data), state}
      end

      def handle_call_custom_default(msg, _from, state) do
        IO.warn("Unhandled call: #{inspect(msg)}")
        {:reply, {:error, :not_implemented}, state}
      end

      defoverridable handle_register_default: 3,
                     handle_get_default: 3,
                     handle_list_default: 2,
                     handle_call_custom_default: 3
    end
  end
end
