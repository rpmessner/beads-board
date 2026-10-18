defmodule Foreman.TicketSheet do
  @moduledoc "URL-driven sheet visibility. The selected stable key is event data."
  use Foreman.Fsm
  initial(:closed)
  state(:closed)
  state(:open)
  event(:params)
  guard(:selected?)
  transition(:params, from: :any, to: :open, guard: :selected?)
  transition(:params, from: :any, to: :closed)

  def selected?(_, %{ticket: ticket}), do: not is_nil(ticket)

  def key(value) when is_binary(value) do
    case String.split(value, ":", parts: 2) do
      [repo, id] when repo != "" and id != "" -> {repo, id}
      _ -> nil
    end
  end

  def key(_), do: nil

  @doc "Normalizes the URL tab value; missing or unknown values select Overview."
  def tab(value) when value in ~w(overview history sessions notes requests), do: value
  def tab(_), do: "overview"

  def tab_path(uri, tab) do
    uri = URI.parse(uri)
    params = URI.decode_query(uri.query || "") |> Map.put("tab", tab(tab))
    (uri.path || "/") <> "?" <> URI.encode_query(params)
  end

  def path(uri, key \\ nil) do
    uri = URI.parse(uri)
    params = URI.decode_query(uri.query || "") |> Map.drop(["ticket", "tab"])

    params =
      if key, do: Map.put(params, "ticket", elem(key, 0) <> ":" <> elem(key, 1)), else: params

    query = URI.encode_query(params)
    (uri.path || "/") <> if(query == "", do: "", else: "?" <> query)
  end
end
