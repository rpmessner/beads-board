defmodule Foreman.TestDatabase do
  @moduledoc "Fail the suite on committed fixture leaks; never erase evidence to make tests pass."

  def assert_clean! do
    leaked =
      Ecto.Adapters.SQL.Sandbox.unboxed_run(Foreman.Repo, fn ->
        %{rows: tables} =
          Foreman.Repo.query!("""
          SELECT tablename FROM pg_tables
          WHERE schemaname = 'public'
            AND tablename NOT IN ('schema_migrations', 'oban_peers')
          ORDER BY tablename
          """)

        for [table] <- tables,
            quoted = "\"" <> String.replace(table, "\"", "\"\"") <> "\"",
            %{rows: [[count]]} = Foreman.Repo.query!("SELECT count(*) FROM " <> quoted),
            count > 0,
            do: {table, count}
      end)

    if leaked != [] do
      raise "Committed test data in #{Foreman.Repo.config()[:database]}: #{inspect(leaked)}. " <>
              "Use MIX_ENV=acceptance for live fixtures; register cleanup before committed integration writes."
    end

    :ok
  end
end
