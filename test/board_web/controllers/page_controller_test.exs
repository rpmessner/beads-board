defmodule BoardWeb.PageControllerTest do
  use BoardWeb.ConnCase
  import Phoenix.LiveViewTest

  test "home opens the configured-repository foundation", %{conn: conn} do
    {:ok, view, _} = live(conn, "/")
    assert has_element?(view, "#config-status")
    assert has_element?(view, "nav[aria-label=Main]")
  end
end
