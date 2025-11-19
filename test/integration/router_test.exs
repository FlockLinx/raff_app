defmodule RaffApp.Web.RouterTest do
  use ExUnit.Case, async: false
  import Plug.Test

  @opts RaffApp.Web.Router.init([])

  setup do
    RaffApp.UserRegistry.clear()
    RaffApp.RaffleManager.clear()
    :ok
  end

  test "returns 404 for unknown routes" do
    conn = conn(:get, "/unknown")
    conn = RaffApp.Web.Router.call(conn, @opts)
    assert conn.status == 404
  end

  test "validates draw_date format" do
    conn = conn(:post, "/raffles", %{"name" => "Test", "draw_date" => "invalid-date"})
    conn = RaffApp.Web.Router.call(conn, @opts)
    assert conn.status == 400
    assert Jason.decode!(conn.resp_body)["error"] =~ "Invalid draw_date"
  end

  test "handles missing parameters gracefully" do
    # Sem name
    conn = conn(:post, "/raffles", %{"draw_date" => "2024-01-01T00:00:00Z"})
    conn = RaffApp.Web.Router.call(conn, @opts)
    assert conn.status == 400

    conn = conn(:post, "/raffles/1/participate", %{})
    conn = RaffApp.Web.Router.call(conn, @opts)
    assert conn.status == 400
  end

  test "returns proper error for raffle not found" do
    conn = conn(:get, "/raffles/999/result")
    conn = RaffApp.Web.Router.call(conn, @opts)
    assert conn.status == 404
  end
end
