defmodule Foreman.DocumentPanel do
  @moduledoc "URL-driven document layer, independent of the ticket layer."
  use Foreman.Fsm
  initial(:closed)
  state(:closed)
  state(:open)
  state(:unavailable)
  event(:open)
  event(:missing)
  event(:close)
  transition(:open, from: :any, to: :open)
  transition(:missing, from: :any, to: :unavailable)
  transition(:close, from: :any, to: :closed)

  @doc "The repo and path encoded in a doc parameter, or nil."
  def key(value) when is_binary(value) do
    case String.split(value, ":", parts: 2) do
      [repo, path] when repo != "" and path != "" -> {repo, path}
      _ -> nil
    end
  end

  def key(_), do: nil

  @doc "Change only the document layer; doc_source is reserved for a validated source."
  def path(uri, document \\ nil) do
    uri = URI.parse(uri)
    params = URI.decode_query(uri.query || "") |> Map.drop(["doc", "doc_source"])
    params = if document, do: Map.merge(params, document), else: params
    query = URI.encode_query(params)
    (uri.path || "/") <> if(query == "", do: "", else: "?" <> query)
  end

  def link_params(href) when is_binary(href) do
    uri = URI.parse(href)

    with nil <- uri.host,
         nil <- uri.scheme,
         "/documents/" <> repo when repo != "" <- uri.path,
         false <- String.contains?(repo, "/"),
         %{"path" => path} = query when path != "" <- URI.decode_query(uri.query || "") do
      doc = URI.decode(repo) <> ":" <> path

      if query["source"],
        do: %{"doc" => doc, "doc_source" => query["source"]},
        else: %{"doc" => doc}
    else
      _ -> nil
    end
  end

  def link_params(_), do: nil
end
