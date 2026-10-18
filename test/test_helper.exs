Mimic.copy(Phoenix.Token)
Mimic.copy(File)

ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(Board.Repo, :manual)
Board.TestDatabase.assert_clean!()
ExUnit.after_suite(fn _ -> Board.TestDatabase.assert_clean!() end)
