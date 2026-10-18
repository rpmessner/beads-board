defmodule Board.AgentToken do
  @moduledoc """
  Read-only local bearer credential. The file's location comes only from
  configuration or BOARD_TOKEN_FILE (set in an untracked env file); no default path
  is compiled in, so no secret location appears in the repository. Unset, missing or
  empty fails closed.
  """
  def read do
    path = Application.get_env(:board, :token_file) || System.get_env("BOARD_TOKEN_FILE")

    with path when is_binary(path) and path != "" <- path,
         {:ok, text} <- File.read(path),
         token when byte_size(token) >= 16 <- String.trim(text) do
      {:ok, token}
    else
      _ -> {:error, :token_unavailable}
    end
  end
end
