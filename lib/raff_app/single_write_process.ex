defmodule RaffApp.SingleWriterProcess do
  defmacro __using__(_opts) do
    quote do
      use GenServer

      def start_link(process_id, process_data) do
        GenServer.start_link(__MODULE__, {process_id, process_data},
          name: process_name(process_id)
        )
      end

      def draw_winner(process_id) do
        GenServer.call(process_name(process_id), :draw_winner)
      end

      def get_winner(process_id) do
        GenServer.call(process_name(process_id), :get_winner)
      end

      def participate(process_id, user_id) do
        GenServer.call(process_name(process_id), {:participate, user_id, DateTime.utc_now()})
      end

      def get_participants(process_id) do
        GenServer.call(process_name(process_id), :get_participants)
      end

      def get_state(process_id) do
        GenServer.call(process_name(process_id), :get_state)
      end

      def get_status(process_id) do
        GenServer.call(process_name(process_id), :get_status)
      end

      defp process_name(process_id) do
        {:via, Registry, {RaffApp.ParticipantRegistry, process_id}}
      end

      def init({process_id, process_data}) do
        {:ok,
         %{
           process_id: process_id,
           process_data: process_data,
           participants: %{},
           participant_ids: MapSet.new(),
           status: :open,
           winner: nil
         }}
      end

      def handle_call(msg, from, state) do
        case msg do
          {:participate, user_id, now} ->
            handle_participate(user_id, now, from, state)

          :get_participants ->
            handle_get_participants(from, state)

          :get_state ->
            handle_get_state(from, state)

          :get_status ->
            handle_get_status(from, state)

          :draw_winner ->
            handle_draw_winner(from, state)

          :get_winner ->
            handle_get_winner(from, state)

          custom_msg ->
            if function_exported?(__MODULE__, :handle_call_custom, 3) do
              apply(__MODULE__, :handle_call_custom, [custom_msg, from, state])
            else
              {:reply, {:error, :not_implemented}, state}
            end
        end
      end

      def handle_get_winner(_from, state) do
        {:reply, {:error, :not_implemented}, state}
      end

      def handle_participate(user_id, now, _from, state) do
        {:reply, :ok, state}
      end

      def handle_get_participants(_from, %{participants: participants} = state) do
        {:reply, Map.values(participants), state}
      end

      def handle_get_state(_from, state) do
        {:reply, state, state}
      end

      def handle_get_status(_from, state) do
        {:reply, {:error, :not_implemented}, state}
      end

      def handle_draw_winner(_from, state) do
        {:reply, {:error, :not_implemented}, state}
      end

      defoverridable handle_participate: 4,
                     handle_get_participants: 2,
                     handle_get_state: 2,
                     handle_get_status: 2,
                     handle_draw_winner: 2,
                     handle_get_winner: 2
    end
  end
end
