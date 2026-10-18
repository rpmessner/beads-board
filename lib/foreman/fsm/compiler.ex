defmodule Foreman.Fsm.Compiler do
  @moduledoc false

  def compile(declarations, opts, env) do
    ds =
      Enum.map(declarations, fn {kind, name, opts, file, line} ->
        %{kind: kind, name: name, opts: opts, file: file, line: line}
      end)

    origin = %{file: env.file, line: env.line}
    initials = Enum.filter(ds, &(&1.kind == :initial))

    if length(initials) != 1,
      do:
        fail(
          List.last(initials) || origin,
          "exactly one initial is required (got #{length(initials)})"
        )

    options!(opts, [:observed_never_invalid], :machine, origin)

    unless is_boolean(Keyword.get(opts, :observed_never_invalid, false)),
      do: fail(origin, "observed_never_invalid must be a boolean")

    Enum.each(ds, &validate_declaration!/1)

    for kind <- [:state, :event, :group, :guard] do
      ds
      |> Enum.filter(&(&1.kind == kind))
      |> Enum.reduce(MapSet.new(), fn d, seen ->
        if MapSet.member?(seen, d.name), do: fail(d, "duplicate #{kind} #{inspect(d.name)}")
        MapSet.put(seen, d.name)
      end)
    end

    states = for d <- ds, d.kind == :state, do: d.name
    events = for d <- ds, d.kind == :event, do: d.name
    groups = Map.new(for d <- ds, d.kind == :group, do: {d.name, d.opts})
    guards = for d <- ds, d.kind == :guard, do: d.name
    effects = for d <- ds, d.kind == :effects, name <- d.name, do: name
    initial = hd(initials)
    declared!(initial.name, states, :state, initial)

    for d <- ds do
      case d.kind do
        :group ->
          if d.name in states, do: fail(d, "group #{inspect(d.name)} conflicts with a state")
          for name <- d.opts, do: declared!(name, states, :state, d)

        :state ->
          effect_names!(
            Keyword.get(d.opts, :enter, []) ++ Keyword.get(d.opts, :exit, []),
            effects,
            d
          )

        :guard ->
          unless Module.defines?(env.module, {d.name, 2}, :def),
            do: fail(d, "guard #{inspect(d.name)} requires public def #{d.name}/2")

        _ ->
          :ok
      end
    end

    rows =
      ds
      |> Enum.filter(&(&1.kind in [:transition, :ignore, :invalid]))
      |> Enum.with_index()
      |> Enum.map(fn {d, id} ->
        from = Keyword.get(d.opts, :from)
        {from_states, state_rank} = selector(from, states, groups, :state, d)
        {on_events, event_rank} = selector(d.name, events, %{}, :event, d)
        fx = Keyword.get(d.opts, :do, [])

        if d.kind != :transition and fx != [],
          do: fail(d, "ignore/invalid rows cannot have effects")

        effect_names!(fx, effects, d)
        guard = Keyword.get(d.opts, :guard)
        if not is_nil(guard), do: declared!(guard, guards, :guard, d)
        to = if d.kind == :transition, do: Keyword.get(d.opts, :to), else: :stay
        if to != :stay, do: declared!(to, states, :state, d)

        if Keyword.get(opts, :observed_never_invalid, false) and d.kind == :invalid do
          for event <- on_events do
            if Enum.any?(
                 ds,
                 &(&1.kind == :event and &1.name == event and &1.opts[:source] == :observed)
               ),
               do: fail(d, "observed event #{inspect(event)} cannot be invalid")
          end
        end

        Map.merge(d, %{
          id: id,
          from: from,
          from_states: from_states,
          events: on_events,
          rank: {state_rank, event_rank},
          guard: guard,
          to: to,
          effects: fx
        })
      end)

    choices =
      for state <- states, event <- events, into: %{} do
        candidates =
          rows
          |> Enum.filter(&(state in &1.from_states and event in &1.events))
          |> Enum.sort_by(&{&1.rank, &1.id})

        pair = "(#{inspect(state)}, #{inspect(event)})"

        if candidates == [],
          do: fail(origin, "no row for #{pair}; add a transition, ignore or invalid")

        Enum.reduce(candidates, MapSet.new(), fn row, seen ->
          key = {row.rank, row.guard}

          if MapSet.member?(seen, key),
            do: fail(row, "duplicate rows for #{pair} with equal rank and guard")

          MapSet.put(seen, key)
        end)

        unless Enum.any?(candidates, &is_nil(&1.guard)),
          do: fail(hd(candidates), "every row for #{pair} is guarded; add an unguarded fallback")

        {guarded, [fallback | _]} = Enum.split_while(candidates, & &1.guard)
        {{state, event}, guarded ++ [fallback]}
      end

    used = choices |> Map.values() |> List.flatten() |> MapSet.new(& &1.id)

    for row <- rows,
        not MapSet.member?(used, row.id),
        do: fail(row, "dead row; earlier or more specific rows decide every pair it names")

    reached = reachable(MapSet.new([initial.name]), choices)

    for d <- ds,
        d.kind == :state,
        not MapSet.member?(reached, d.name),
        do: fail(d, "state #{inspect(d.name)} is unreachable from #{inspect(initial.name)}")

    %{
      initial: initial.name,
      states: states,
      events: events,
      groups: groups,
      rows: rows,
      choices: choices,
      state_effects:
        Map.new(
          for d <- ds,
              d.kind == :state,
              do:
                {d.name,
                 %{enter: Keyword.get(d.opts, :enter, []), exit: Keyword.get(d.opts, :exit, [])}}
        ),
      sources:
        Map.new(
          for d <- ds, d.kind == :event, do: {d.name, Keyword.get(d.opts, :source, :claimed)}
        )
    }
  end

  defp selector(:any, names, _groups, _kind, _d), do: {names, 2}

  defp selector(names, declared, _groups, kind, d) when is_list(names) do
    if names == [], do: fail(d, "selector requires a non-empty list of names")
    for name <- names, do: declared!(name, declared, kind, d)
    {Enum.uniq(names), 1}
  end

  defp selector(name, names, groups, kind, d) do
    cond do
      name in names ->
        {[name], 0}

      Map.has_key?(groups, name) ->
        {Map.fetch!(groups, name), 1}

      true ->
        fail(
          d,
          "undeclared #{if kind == :state, do: "state or group", else: "event"} #{inspect(name)}"
        )
    end
  end

  defp effect_names!(fx, effects, d) do
    effects_shape!(fx, d)
    for {name, _arg} <- fx, do: declared!(name, effects, :effect, d)
  end

  defp validate_declaration!(d) do
    case d.kind do
      :initial ->
        :ok

      :effects ->
        unless is_list(d.name), do: fail(d, "effects declaration requires a list of names")
        Enum.each(d.name, &name!(&1, :effect, d))

      :group ->
        name!(d.name, d.kind, d)

        unless is_list(d.opts) and d.opts != [],
          do: fail(d, "group requires a non-empty list of state names")

      :guard ->
        name!(d.name, d.kind, d)

      :state ->
        name!(d.name, d.kind, d)
        options!(d.opts, [:enter, :exit], d.kind, d)
        effects_shape!(Keyword.get(d.opts, :enter, []), d)
        effects_shape!(Keyword.get(d.opts, :exit, []), d)

      :event ->
        name!(d.name, d.kind, d)
        options!(d.opts, [:source], d.kind, d)

        unless Keyword.get(d.opts, :source, :claimed) in [:claimed, :observed],
          do: fail(d, "event source must be :claimed or :observed")

      :transition ->
        options!(d.opts, [:from, :to, :guard, :do], d.kind, d)

      kind when kind in [:ignore, :invalid] ->
        options!(d.opts, [:from, :guard, :do], d.kind, d)
    end
  end

  defp name!(name, kind, d) do
    pattern =
      if kind in [:state, :group], do: ~r/^[a-z][a-z0-9_]*$/, else: ~r/^[a-z][a-z0-9_]*[?!]?$/

    unless is_atom(name) and name not in [nil, true, false, :any, :stay] and
             Regex.match?(pattern, Atom.to_string(name)) and
             not String.starts_with?(Atom.to_string(name), "fsm_"),
           do: fail(d, "invalid #{kind} name #{inspect(name)}")
  end

  defp options!(opts, allowed, kind, d) do
    unless Keyword.keyword?(opts), do: fail(d, "#{kind} options must be a keyword list")

    Enum.reduce(opts, MapSet.new(), fn {key, _}, seen ->
      unless key in allowed, do: fail(d, "unknown #{kind} option #{inspect(key)}")
      if MapSet.member?(seen, key), do: fail(d, "duplicate #{kind} option #{inspect(key)}")
      MapSet.put(seen, key)
    end)
  end

  defp effects_shape!(fx, d) do
    unless Keyword.keyword?(fx),
      do: fail(d, "effects must be a keyword list of {name, argument} tuples")
  end

  defp declared!(name, names, kind, d) do
    unless name in names, do: fail(d, "undeclared #{kind} #{inspect(name)}")
  end

  defp reachable(seen, choices) do
    next =
      Enum.reduce(choices, seen, fn {{state, _}, rows}, acc ->
        if MapSet.member?(seen, state) do
          Enum.reduce(rows, acc, fn row, acc ->
            if row.kind == :transition and row.to != :stay, do: MapSet.put(acc, row.to), else: acc
          end)
        else
          acc
        end
      end)

    if next == seen, do: seen, else: reachable(next, choices)
  end

  defp fail(d, message),
    do: raise(CompileError, file: d.file, line: d.line, description: "fsm: " <> message)
end
