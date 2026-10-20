defmodule Foreman.DocumentPanelTest do
  use ExUnit.Case, async: true
  alias Foreman.DocumentPanel

  for state <- [:closed, :open, :unavailable],
      {event, expected} <- [open: :open, missing: :unavailable, close: :closed] do
    test "#{state} + #{event} -> #{expected}" do
      assert DocumentPanel.step(unquote(state), unquote(event), %{}) == {unquote(expected), []}
    end
  end

  test "viewer links carry a document source without granting it filesystem access" do
    assert DocumentPanel.link_params("/documents/sample?path=docs%2Fspec.md&source=build-1") ==
             %{"doc" => "sample:docs/spec.md", "doc_source" => "build-1"}

    for href <- [
          "https://other.test/documents/sample?path=README.md",
          "//other.test/documents/sample?path=README.md",
          "/documents/sample",
          "/documents/sample/other?path=x.md",
          nil
        ] do
      assert DocumentPanel.link_params(href) == nil
    end
  end

  test "document URL changes preserve the ticket, tab, filters and page path" do
    uri =
      "/epics/sample/e?ticket=sample%3As-1&tab=notes&project=sample&doc=old%3Aone.md&doc_source=old"

    assert DocumentPanel.path(uri, %{"doc" => "sample:docs/spec.md"}) ==
             "/epics/sample/e?doc=sample%3Adocs%2Fspec.md&project=sample&tab=notes&ticket=sample%3As-1"

    assert DocumentPanel.path(uri) ==
             "/epics/sample/e?project=sample&tab=notes&ticket=sample%3As-1"

    assert DocumentPanel.key("sample:docs/name:part.md") == {"sample", "docs/name:part.md"}
    assert DocumentPanel.key(["bad"]) == nil
  end

  test "opening a document never changes ticket data" do
    data = %{ticket: {"sample", "s-1"}}

    assert DocumentPanel.step(:closed, {:open, %{repo: "sample", path: "README.md"}}, data) ==
             {:open, []}
  end
end
