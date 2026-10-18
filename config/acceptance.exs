import Config
import_config "test.exs"

checkout = Path.basename(Path.expand("..", __DIR__))

# The live acceptance server commits fixtures; it must never use a unit-test DB.
config :foreman, Foreman.Repo,
  database: "foreman_acceptance_#{checkout}",
  pool: DBConnection.ConnectionPool,
  pool_size: 5

config :foreman, config_directory: Path.expand("../tmp/cli-config", __DIR__)
