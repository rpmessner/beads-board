defmodule Board.TicketSheet do
  @moduledoc "URL-driven sheet visibility. The selected stable key is event data."
  use Board.Fsm
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

  def path(uri, key \\ nil) do
    uri = URI.parse(uri)
    params = URI.decode_query(uri.query || "") |> Map.delete("ticket")

    params =
      if key, do: Map.put(params, "ticket", elem(key, 0) <> ":" <> elem(key, 1)), else: params

    query = URI.encode_query(params)
    (uri.path || "/") <> if(query == "", do: "", else: "?" <> query)
  end
end
