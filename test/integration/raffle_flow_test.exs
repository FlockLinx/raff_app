defmodule RaffApp.RaffleFlowTest do
  use ExUnit.Case, async: false
  import Plug.Test

  alias RaffApp.Web.Router

  @opts Router.init([])

  setup do
    RaffApp.UserRegistry.clear()
    RaffApp.RaffleManager.clear()
    :ets.delete_all_objects(:raffle_backup)
    :ok
  end

  describe "complete raffle flow" do
    test "full raffle lifecycle" do
      user1 = register_user("User One", "user1@test.com")
      user2 = register_user("User Two", "user2@test.com")

      raffle = create_raffle("Test Raffle", DateTime.add(DateTime.utc_now(), 3600))

      assert participate(raffle["id"], user1["id"]) == "participated"
      assert participate(raffle["id"], user2["id"]) == "participated"

      draw_winner(raffle["id"])
      
      result = get_result(raffle["id"])

      assert result["raffle_id"] == raffle["id"]
      assert result["raffle_name"] == "Test Raffle"
      assert result["winner"]["id"] in [user1["id"], user2["id"]]
      assert result["winner"]["name"] in ["User One", "User Two"]
    end
  end

  defp register_user(name, email) do
    conn = conn(:post, "/users", %{"name" => name, "email" => email})
    conn = Router.call(conn, @opts)

    assert conn.status == 201
    Jason.decode!(conn.resp_body)
  end

  defp create_raffle(name, draw_date) do
    conn =
      conn(:post, "/raffles", %{
        "name" => name,
        "draw_date" => DateTime.to_iso8601(draw_date)
      })

    conn = Router.call(conn, @opts)

    assert conn.status == 201
    Jason.decode!(conn.resp_body)
  end

  defp participate(raffle_id, user_id) do
    conn = conn(:post, "/raffles/#{raffle_id}/participate", %{"user_id" => user_id})
    conn = Router.call(conn, @opts)

    assert conn.status == 200
    Jason.decode!(conn.resp_body)["status"]
  end

  defp draw_winner(raffle_id) do
    conn = conn(:post, "/raffles/#{raffle_id}/draw", %{})
    conn = Router.call(conn, @opts)

    assert conn.status == 200
    Jason.decode!(conn.resp_body)["winner"]
  end

  defp get_result(raffle_id) do
    conn = conn(:get, "/raffles/#{raffle_id}/result", %{})
    conn = Router.call(conn, @opts)

    assert conn.status == 200
    Jason.decode!(conn.resp_body)
  end
end
