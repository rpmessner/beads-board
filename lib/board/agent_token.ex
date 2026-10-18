defmodule Board.AgentToken do
  @moduledoc "Read-only local bearer credential. Missing or empty files fail closed."
  def read do
    path =
      Application.get_env(:board, :token_file) || System.get_env("BOARD_TOKEN_FILE") ||
        Path.expand("~/.ssh/beads-board-token")

    with {:ok, text} <- File.read(path), token when byte_size(token) >= 16 <- String.trim(text) do
      {:ok, token}
    else
      _ -> {:error, :token_unavailable}
    end
  end
end
