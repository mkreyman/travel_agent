defmodule TravelAgentWeb.ChatLiveTest do
  use TravelAgentWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "ChatLive" do
    test "mounts and displays header", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Travel Agent"
      assert html =~ "Your friendly travel planning assistant"
    end

    test "displays empty message list initially", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      # Should have the messages container but no user messages
      assert html =~ ~s(id="messages")
      # Messages div should be empty (no message bubbles)
      refute html =~ ~s(class="p-3 rounded-lg)
    end
  end
end
