defmodule Board.Fsm.Runtime do
  @moduledoc false

  def step(machine, module, state, event, data) do
    {name, payload} =
      case event do
        {name, payload} when is_atom(name) -> {name, payload}
        name when is_atom(name) -> {name, nil}
        _ -> {nil, nil}
      end

    row =
      machine.choices
      |> Map.get({state, name}, [])
      |> Enum.find(fn row ->
        is_nil(row.guard) or apply(module, row.guard, [data, payload]) == true
      end)

    case row do
      %{kind: :ignore} ->
        {state, []}

      %{kind: :transition} = row ->
        next = if row.to == :stay, do: state, else: row.to

        fx =
          if next == state,
            do: row.effects,
            else:
              machine.state_effects[state].exit ++
                row.effects ++ machine.state_effects[next].enter

        {next, fx}

      _ ->
        {:error, {:invalid, state, event}}
    end
  end
end
