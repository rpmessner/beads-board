defmodule Board.Requests.Kind do
  @moduledoc "Creation validation and transactional approval extension point. Jobs must revalidate live facts and claim once before IO."
  @callback validate(map(), map()) :: {:ok, map()} | {:error, atom()}
  @callback enqueue(Board.Requests.Request.t()) :: :ok | {:error, atom()}

  def fetch("decision"), do: {:ok, Board.Requests.Decision}
  def fetch(_), do: {:error, :unsupported_kind}
end
