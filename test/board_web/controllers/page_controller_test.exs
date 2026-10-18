defmodule BoardWeb.PageControllerTest do
  use BoardWeb.ConnCase
  import Phoenix.LiveViewTest

  test "home opens initiatives", %{conn: conn} do
    {:ok, view, _} = live(conn, "/")
    assert has_element?(view, "#epics-panel")
    assert has_element?(view, "nav[aria-label=Main]")
  end
end
