defmodule RaffApp.Web.Router do
  use Plug.Router

  plug(:match)
  plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
  plug(:dispatch)

  post "/users" do
    case conn.body_params do
      %{"name" => name, "email" => email} when name != "" and email != "" ->
        user_id = System.unique_integer([:positive])

        case RaffApp.UserRegistry.register(user_id, %{id: user_id, name: name, email: email}) do
          {:ok, _} ->
            send_json(conn, 201, %{id: user_id, name: name, email: email})

          _ ->
            send_json(conn, 400, %{error: "Failed to register user"})
        end

      _ ->
        send_json(conn, 400, %{error: "Missing or empty name/email parameters"})
    end
  end

  post "/raffles" do
    case conn.body_params do
      %{"name" => name, "draw_date" => draw_date_str} when name != "" ->
        case DateTime.from_iso8601(draw_date_str) do
          {:ok, draw_date, _offset} ->
            case RaffApp.RaffleManager.create_raffle(name, draw_date) do
              {:ok, raffle} ->
                case RaffApp.RaffleParticipantSupervisor.start_raffle_participant(
                       raffle.id,
                       draw_date
                     ) do
                  {:ok, _pid} ->
                    send_json(conn, 201, %{
                      id: raffle.id,
                      name: raffle.name,
                      draw_date: draw_date_str,
                      status: "open"
                    })

                  {:error, {:already_started, _pid}} ->
                    send_json(conn, 201, %{
                      id: raffle.id,
                      name: raffle.name,
                      draw_date: draw_date_str,
                      status: "open"
                    })

                  error ->
                    IO.inspect(error, label: "Failed to start RaffleParticipant")
                    send_json(conn, 500, %{error: "Failed to initialize raffle"})
                end

              _ ->
                send_json(conn, 400, %{error: "Failed to create raffle"})
            end

          {:error, _} ->
            send_json(conn, 400, %{error: "Invalid draw_date. Use ISO8601 format"})
        end

      _ ->
        send_json(conn, 400, %{error: "Missing or empty name parameter"})
    end
  end

  post "/raffles/:raffle_id/participate" do
    case conn.body_params do
      %{"user_id" => user_id}
      when is_integer(user_id) or (is_binary(user_id) and user_id != "") ->
        raffle_id = String.to_integer(raffle_id)

        case RaffApp.RaffleParticipant.participate(raffle_id, user_id) do
          :ok ->
            send_json(conn, 200, %{status: "participated"})

          {:error, :already_participated} ->
            send_json(conn, 409, %{error: "User already participated"})

          {:error, :raffle_expired} ->
            send_json(conn, 410, %{error: "Raffle has expired"})

          {:error, :raffle_closed} ->
            send_json(conn, 410, %{error: "Raffle is closed"})

          _ ->
            send_json(conn, 404, %{error: "Raffle not found"})
        end

      _ ->
        send_json(conn, 400, %{error: "Missing or invalid user_id parameter"})
    end
  end

  get "/raffles/:raffle_id/result" do
    raffle_id = String.to_integer(raffle_id)

    with {:ok, raffle} <- RaffApp.RaffleManager.find(raffle_id) do
      winner_id = RaffApp.RaffleParticipant.get_winner(raffle_id)

      cond do
        winner_id != nil ->
          winner_user = RaffApp.UserRegistry.get(winner_id)

          if winner_user do
            send_json(conn, 200, %{
              raffle_id: raffle_id,
              raffle_name: raffle.name,
              winner: %{
                id: winner_user.id,
                name: winner_user.name,
                email: winner_user.email
              }
            })
          else
            send_json(conn, 500, %{error: "Winner user not found"})
          end

        DateTime.compare(DateTime.utc_now(), raffle.draw_date) == :gt ->
          send_json(conn, 422, %{error: "Raffle draw pending - please contact administrator"})

        true ->
          send_json(conn, 422, %{error: "Raffle not drawn yet"})
      end
    else
      {:error, :not_found} ->
        send_json(conn, 404, %{error: "Raffle not found"})

      _ ->
        send_json(conn, 500, %{error: "Internal server error"})
    end
  end

  post "/raffles/:raffle_id/draw" do
    raffle_id = String.to_integer(raffle_id)

    case RaffApp.RaffleManager.find(raffle_id) do
      {:ok, _raffle} ->
        case Registry.lookup(RaffApp.ParticipantRegistry, raffle_id) do
          [{_pid, _}] ->
            case RaffApp.RaffleParticipant.draw_winner(raffle_id) do
              {:ok, winner_id} ->
                winner_user = RaffApp.UserRegistry.get(winner_id)

                send_json(conn, 200, %{
                  winner: %{
                    id: winner_user.id,
                    name: winner_user.name,
                    email: winner_user.email
                  }
                })

              {:error, :no_participants} ->
                send_json(conn, 422, %{error: "No participants"})

              {:error, :raffle_not_open} ->
                send_json(conn, 409, %{error: "Raffle is not open for drawing"})

              _ ->
                send_json(conn, 500, %{error: "Internal server error during draw"})
            end
        end
    end
  end

  get "/raffles/:raffle_id/status" do
    raffle_id = String.to_integer(raffle_id)

    case RaffApp.RaffleParticipant.get_status(raffle_id) do
      {:error, _} ->
        send_json(conn, 404, %{error: "Raffle not found"})

      status_info ->
        send_json(conn, 200, status_info)
    end
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end

  defp send_json(conn, status, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(data))
  end
end
