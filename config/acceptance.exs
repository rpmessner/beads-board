import Config
import_config "test.exs"

checkout = Path.basename(Path.expand("..", __DIR__))

# The live acceptance server commits fixtures; it must never use a unit-test DB.
config :board, Board.Repo,
  database: "beads_board_acceptance_#{checkout}",
  pool: DBConnection.ConnectionPool,
  pool_size: 5

config :board, config_directory: Path.expand("../tmp/cli-config", __DIR__)
