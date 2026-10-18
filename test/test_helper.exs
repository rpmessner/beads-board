ExUnit.start()

if Application.get_env(:board, :start_repo, true) do
  Ecto.Adapters.SQL.Sandbox.mode(Board.Repo, :manual)
end
