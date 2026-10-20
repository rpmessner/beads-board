defmodule Foreman.TicketDocumentsTest do
  use ExUnit.Case, async: true
  alias Foreman.TicketDocuments

  setup do
    root = Foreman.ScratchDocs.dir("ticket-documents")

    Foreman.ScratchDocs.write(
      root,
      Map.new(~w(body note history question answer session), &{"#{&1}.md", "# #{&1}"})
    )

    on_exit(fn -> File.rm_rf!(root) end)
    %{root: root, repos: [%{"key" => "sample", "path" => root}]}
  end

  test "collects worktree sources and dedupes relative and absolute mentions" do
    f = Foreman.WorktreeDocs.fixture()
    on_exit(fn -> File.rm_rf!(f.base) end)
    ticket = %{f.ticket | raw: %{"description" => "docs/report.md #{f.tree}/docs/report.md"}}
    assert [{"sample", "docs/report.md", source}] = TicketDocuments.collect(ticket, [], f.repos)
    assert source == Foreman.DocumentSources.token(f.tree)
    Foreman.ScratchDocs.write(f.root, %{"docs/report.md" => "# Main"})
    assert TicketDocuments.collect(ticket, [], f.repos) == [{"sample", "docs/report.md", :main}]
  end

  test "relative, dotted and absolute mentions identify the same document", %{
    repos: repos,
    root: root
  } do
    ticket = %{
      repo: "sample",
      raw: %{"description" => "./body.md body.md #{root}/body.md"},
      sessions: [],
      notes: [],
      history: []
    }

    assert TicketDocuments.collect(ticket, [], repos) == [{"sample", "body.md", :main}]
  end

  test "caps the list at 50 distinct documents across texts and ignores unsafe paths", %{
    repos: repos,
    root: root
  } do
    for n <- 1..60, do: Foreman.ScratchDocs.write(root, %{"#{n}.md" => "# #{n}"})

    ticket = %{
      repo: "sample",
      raw: %{"description" => "body.md ../body.md absent.md notes.txt /etc/passwd.md"},
      sessions: [],
      notes: [],
      history:
        for(
          n <- 1..60,
          do: %{
            inserted_at: DateTime.add(~U[2026-10-19 00:00:00Z], n),
            payload: %{"body" => "#{n}.md"}
          }
        )
    }

    docs = TicketDocuments.collect(ticket, [], repos)
    assert length(docs) == 50
    assert hd(docs) == {"sample", "60.md", :main}
    assert List.last(docs) == {"sample", "11.md", :main}

    assert TicketDocuments.collect(%{ticket | history: []}, [], repos) == [
             {"sample", "body.md", :main}
           ]
  end

  test "renders bare and Markdown paths only when the shared resolver finds them", %{
    repos: repos,
    root: root
  } do
    html =
      TicketDocuments.render(
        "body.md [note](note.md) [missing](missing.md) [outside](../body.md) `#{root}/history.md`",
        "sample",
        repos
      )

    assert LazyHTML.query(LazyHTML.from_fragment(html), "a[href='']") |> Enum.empty?()

    assert html
           |> LazyHTML.from_fragment()
           |> LazyHTML.query("a[href^='/documents/']")
           |> LazyHTML.attribute("href") == [
             "/documents/sample?path=body.md",
             "/documents/sample?path=note.md",
             "/documents/sample?path=history.md"
           ]
  end

  test "collects all text sources, deduping by newest mention", %{repos: repos} do
    ticket = %{
      repo: "sample",
      raw: %{"description" => "body.md history.md"},
      notes: [%{inserted_at: ~U[2026-10-19 03:00:00Z], body: "note.md"}],
      sessions: [
        %{
          started_at: ~U[2026-10-19 02:00:00Z],
          last_seen_at: ~U[2026-10-19 06:00:00Z],
          details: %{"report" => "session.md"}
        }
      ],
      history: [
        %{
          inserted_at: ~U[2026-10-19 05:00:00Z],
          payload: %{"arbitrary" => [%{"nested" => "history.md note.md"}]}
        }
      ]
    }

    requests = [
      %{
        inserted_at: ~U[2026-10-19 01:00:00Z],
        updated_at: ~U[2026-10-19 04:00:00Z],
        facts: %{"question" => "question.md"},
        outcome: %{"answer" => "answer.md"},
        note: nil
      }
    ]

    assert TicketDocuments.collect(ticket, requests, repos) == [
             {"sample", "history.md", :main},
             {"sample", "note.md", :main},
             {"sample", "answer.md", :main},
             {"sample", "session.md", :main},
             {"sample", "question.md", :main},
             {"sample", "body.md", :main}
           ]
  end
end
