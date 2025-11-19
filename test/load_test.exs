defmodule RaffApp.LoadTest do
  @base_url "http://localhost:4000"

  def run_progressive_test do
    IO.puts("🚀 INICIANDO TESTE PROGRESSIVO DE CARGA 🚀")

    test_scenarios = [
      {100, "🚗 Teste Leve"},
      {500, "🚙 Teste Moderado"},
      {1000, "🚐 Teste Médio"},
      {2500, "🚛 Teste Pesado"},
      {5000, "🔥 Teste Épico"},
      {10000, "💥 TESTE EXTREMO"}
    ]

    Enum.each(test_scenarios, fn {user_count, label} ->
      IO.puts("\n#{label}: #{user_count} usuários")
      run_concurrent_users(user_count, 1)
      Process.sleep(2000)
    end)
  end

  def run_concurrent_users(user_count, participations_per_user) do
    IO.puts("🔥 Iniciando: #{user_count} usuários")

    raffle_id = create_raffle()

    start_time = System.monotonic_time()

    tasks =
      for user_id <- 1..user_count do
        Task.async(fn ->
          register_and_participate(user_id, raffle_id, participations_per_user)
        end)
      end

    timeout_ms = min(30_000, user_count * 10)
    results = Task.await_many(tasks, timeout_ms)

    end_time = System.monotonic_time()
    duration = System.convert_time_unit(end_time - start_time, :native, :millisecond)

    successful_participations = Enum.count(results, & &1)
    failed_participations = user_count * participations_per_user - successful_participations

    # ⚠️ CORREÇÃO AQUI - divisão normal, não rem (resto)
    avg_per_user = if user_count > 0, do: round(duration / user_count), else: 0

    IO.puts("""
    📊 RESULTADOS:
    ⏱️  Duração: #{duration}ms
    👥 Usuários: #{user_count}
    ✅ Sucessos: #{successful_participations}
    ❌ Falhas: #{failed_participations}
    🚀 Throughput: #{round(successful_participations / max(duration / 1000, 1))} req/seg
    📈 Performance: #{avg_per_user}ms por usuário
    """)

    successful_participations
  end

  defp create_raffle do
    draw_date = DateTime.add(DateTime.utc_now(), 3600) |> DateTime.to_iso8601()

    body =
      Jason.encode!(%{
        "name" => "Load Test Raffle",
        "draw_date" => draw_date
      })

    {:ok, response} =
      HTTPoison.post("#{@base_url}/raffles", body, [{"Content-Type", "application/json"}])

    %{"id" => raffle_id} = Jason.decode!(response.body)
    raffle_id
  end

  defp register_and_participate(user_id, raffle_id, _participations) do
    email = "user#{user_id}@test.com"
    body = Jason.encode!(%{"name" => "User #{user_id}", "email" => email})

    try do
      {:ok, response} =
        HTTPoison.post("#{@base_url}/users", body, [{"Content-Type", "application/json"}])

      %{"id" => registered_user_id} = Jason.decode!(response.body)

      body = Jason.encode!(%{"user_id" => registered_user_id})

      case HTTPoison.post("#{@base_url}/raffles/#{raffle_id}/participate", body, [
             {"Content-Type", "application/json"}
           ]) do
        {:ok, %{status_code: 200}} -> 1
        _ -> 0
      end
    rescue
      _ -> 0
    end
  end
end
