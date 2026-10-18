defmodule Foreman.MarkdownTest do
  use ExUnit.Case, async: true

  test "relative Markdown links stay in the project viewer" do
    html =
      Foreman.Markdown.render(
        "[Next](../guide.md#install) [Web](https://example.com) [Escape](../../secret.md)",
        repo: "sample",
        path: "docs/design/spec.md"
      )

    assert html =~ "/documents/sample?path=docs%2Fguide.md#install"
    assert html =~ "href=\"https://example.com\""
    refute html =~ "href=\"../../"
  end

  test "relative traversal cannot be clamped back into the project" do
    html =
      Foreman.Markdown.render("[Escape](../../README.md) [Encoded](%2e%2e/%2e%2e/README.md)",
        repo: "sample",
        path: "docs/spec.md"
      )

    refute html =~ "/documents/"
  end

  test "ticket rendering refuses oversized input before parsing" do
    assert Foreman.Markdown.render(String.duplicate("x", 1_048_577)) == "<p>Content too large</p>"
  end

  test "GFM renders checkboxes, tables, footnotes, autolinks and dual-theme code, but not raw HTML" do
    html =
      Foreman.Markdown.render("""
      - [x] Shipped
      - [ ] Pending

      | Name | Status |
      | --- | --- |
      | Reader | Ready |

      Footnote[^1] https://example.com

      [^1]: Note

      ```elixir
      def hello, do: :world
      ```

      <script>alert('bad')</script>

      <img src=x onerror=alert(1)>

      [unsafe](javascript:alert%281%29)
      """)

    doc = LazyHTML.from_fragment(html)

    assert length(LazyHTML.query(doc, "input[type=checkbox][disabled]") |> LazyHTML.to_tree()) ==
             2

    assert html =~ "<table>"
    assert html =~ "footnote"
    assert html =~ "href=\"https://example.com\""
    assert html =~ "--lumis-light"
    assert html =~ "--lumis-dark"
    refute html =~ "<script"
    refute html =~ "<img"
    refute html =~ "href=\"javascript:"
  end
end
