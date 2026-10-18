defmodule Board.Requests.Decision do
  @moduledoc "A decision records an answer and can never enqueue external work."
  @behaviour Board.Requests.Kind
  @impl true
  def validate(facts, _) when is_map(facts) do
    options = Map.get(facts, "options", [])
    recommendation = facts["recommendation"]

    if text?(facts["question"]) and is_list(options) and length(options) <= 30 and
         Enum.all?(options, &text?/1) and
         (is_nil(recommendation) or recommendation in options) and
         (is_nil(facts["text"]) or text?(facts["text"])) do
      {:ok,
       Map.take(
         Map.put(facts, "options", Enum.uniq(options)),
         ~w(question options recommendation text)
       )}
    else
      {:error, :invalid_facts}
    end
  end

  def validate(_, _), do: {:error, :invalid_facts}
  @impl true
  def enqueue(_), do: {:error, :decision_not_executable}

  def text?(value),
    do: is_binary(value) and String.trim(value) != "" and byte_size(value) <= 20_000
end
