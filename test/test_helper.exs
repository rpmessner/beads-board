Mimic.copy(Phoenix.Token)
Mimic.copy(File)

ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(Foreman.Repo, :manual)
Foreman.TestDatabase.assert_clean!()
ExUnit.after_suite(fn _ -> Foreman.TestDatabase.assert_clean!() end)
