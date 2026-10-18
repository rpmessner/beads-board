defmodule ForemanWeb.AgentAuth do
  @moduledoc false
  import Plug.Conn
  def init(opts), do: opts

  def call(conn, _) do
    with {:ok, token} <- Foreman.AgentToken.read(),
         ["Bearer " <> supplied] <- get_req_header(conn, "authorization"),
         true <- Plug.Crypto.secure_compare(token, supplied) do
      conn
    else
      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: "unauthorized"}))
        |> halt()
    end
  end
end
