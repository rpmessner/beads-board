defmodule ForemanWeb.AgentController do
  use ForemanWeb, :controller

  def show(conn, %{"repo" => repo, "id" => id}) do
    case Foreman.Agent.ensure_entity({repo, id}) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      row ->
        json(conn, %{
          repo: repo,
          id: id,
          stage: row.stage,
          allowed: Foreman.Overlay.allowed_events({repo, id})
        })
    end
  end

  def event(conn, %{"repo" => repo, "id" => id} = params) do
    request = params |> Map.put("repo", repo) |> Map.put("id", id) |> Map.put("action", "event")
    respond(conn, request)
  end

  def command(conn, params), do: respond(conn, params)
  def catalog(conn, _), do: json(conn, %{repos: Foreman.AgentCatalog.list()})

  def sync(conn, %{"repo" => repo}) do
    Foreman.Runtime.ping(repo)
    json(conn, %{sync: "requested"})
  end

  defp respond(conn, request) do
    {status, body} = Foreman.AgentCommands.execute(request)
    conn |> put_status(status) |> json(body)
  end
end
