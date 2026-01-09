defmodule TravelAgentWeb.ChatLiveTest do
  use TravelAgentWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "ChatLive" do
    test "mounts and displays header", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Travel Agent"
      assert html =~ "Your AI-powered travel planning assistant"
    end

    test "displays empty state with suggestions initially", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      # Should have the messages container
      assert html =~ ~s(id="messages")
      # Should show empty state with suggestions
      assert html =~ "Where would you like to go?"
      assert html =~ "Plan a beach vacation"
    end
  end
end
