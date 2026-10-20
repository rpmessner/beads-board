defmodule Foreman.TicketDocuments do
  @moduledoc "Computed document mentions; entries are `{repo, path, :main | source_token}`."
  alias Foreman.{CardText, DocumentSources, Markdown}

  def collect(ticket, requests, repos \\ nil),
    do: do_collect(ticket, requests, repos || CardText.repos())

  defp do_collect(ticket, requests, repos) do
    mentions =
      Enum.map(ticket.history, &{&1.inserted_at, &1.payload}) ++
        Enum.flat_map(requests, fn request ->
          [
            {request.inserted_at, request.facts},
            {request.updated_at, [request.outcome, request.note]}
          ]
        end) ++
        Enum.map(ticket.notes, &{&1.inserted_at, &1.body}) ++
        Enum.map(ticket.sessions, &{&1.started_at, &1.details}) ++
        [{nil, ticket.raw}]

    mentions
    |> Enum.sort_by(fn {at, _} -> timestamp(at) end, :desc)
    |> Stream.flat_map(fn {_, value} ->
      value
      |> strings()
      |> Enum.flat_map(fn text ->
        text
        |> references(ticket, repos)
        |> Enum.map(fn {_, document} -> document end)
      end)
    end)
    |> Stream.uniq()
    |> Enum.take(50)
  end

  def render(value, context, repos \\ nil) do
    text = if is_binary(value), do: value, else: Jason.encode!(value)
    repos = repos || CardText.repos()
    ticket = if is_binary(context), do: %{repo: context, sessions: [], history: []}, else: context

    links =
      text
      |> references(ticket, repos)
      |> Enum.map(fn {path, {key, relative, source}} ->
        {path, viewer_path(key, relative, source)}
      end)
      |> Map.new()

    Markdown.render(text,
      header_ids: false,
      link_paths: &Map.get(links, &1),
      resolve_paths: &Map.get(links, &1)
    )
  end

  def viewer_path(repo, path, :main), do: Markdown.viewer_path(repo, path)

  def viewer_path(repo, path, source),
    do: Markdown.viewer_path(repo, path) <> "&" <> URI.encode_query(%{"source" => source})

  def label(:main, _ticket), do: "main checkout"

  def label(source, ticket) do
    case Enum.find(DocumentSources.recorded(ticket), &(DocumentSources.token(&1) == source)) do
      nil -> "unavailable"
      root -> "in worktree " <> Path.basename(root)
    end
  end

  defp references(text, ticket, repos) do
    text
    |> Markdown.path_candidates()
    |> Enum.take(50)
    |> Enum.flat_map(fn path ->
      case DocumentSources.resolve(path, ticket.repo, repos, ticket) do
        nil -> []
        document -> [{path, document}]
      end
    end)
  end

  defp strings(value) when is_binary(value), do: [value]
  defp strings(value) when is_list(value), do: Enum.flat_map(value, &strings/1)

  defp strings(value) when is_map(value),
    do: value |> Enum.sort() |> Enum.flat_map(fn {_, v} -> strings(v) end)

  defp strings(_), do: []

  defp timestamp(%DateTime{} = at), do: DateTime.to_unix(at, :microsecond)
  defp timestamp(%NaiveDateTime{} = at), do: at |> DateTime.from_naive!("Etc/UTC") |> timestamp()
  defp timestamp(_), do: -1
end
