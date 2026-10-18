defmodule Board.Fsm do
  @moduledoc """
  Compile-checked, pure state machines with effects returned as data.

  Declarations accept literal atoms and lists. Guards are public, pure
  `name(data, payload)` functions returning booleans. They must be total over
  the data/payload domain accepted by the caller; the DSL cannot prove arbitrary
  Elixir functions pure or total. An atom event supplies `nil` as its payload.
  Unknown states/events return the same invalid result as explicit invalid rows.

  Names are lowercase snake-case atoms (guards/events/effects may end in `?` or
  `!`). `:any`, `:stay`, booleans, `nil`, and the `fsm_` prefix are reserved.
  Effects are keyword lists of `{name, argument}` data tuples, not callbacks.
  A group cannot share a state's name. Event source defaults to `:claimed`.

  `__fsm__/1` supports `:initial`, `:states`, `:events`, `:groups`, `:rows`,
  `:sources`, `:state_effects`, and `:choices`. States/events retain declaration
  order. Rows include declaration file/line; choices are resolved alternatives
  keyed by `{state, event}`, ending with the first unguarded fallback.
  Reachability is structural: guards are assumed satisfiable, not executed at
  compile time. The matrix includes effective exit/row/entry effects.
  """

  defmacro __using__(opts) do
    quote do
      import Board.Fsm
      Module.register_attribute(__MODULE__, :fsm_declarations, accumulate: true)
      @fsm_options unquote(opts)
      @before_compile Board.Fsm
    end
  end

  for kind <- [:initial, :guard, :effects] do
    defmacro unquote(kind)(name) do
      declaration(unquote(kind), name, [], __CALLER__)
    end
  end

  for kind <- [:state, :event, :transition, :ignore, :invalid] do
    defmacro unquote(kind)(name, opts \\ []) do
      declaration(unquote(kind), name, opts, __CALLER__)
    end
  end

  defmacro group(name, members), do: declaration(:group, name, members, __CALLER__)

  defp declaration(kind, name, opts, env) do
    quote do
      @fsm_declarations {unquote(kind), unquote(name), unquote(opts), unquote(env.file),
                         unquote(env.line)}
    end
  end

  defmacro __before_compile__(env) do
    declarations = env.module |> Module.get_attribute(:fsm_declarations) |> Enum.reverse()

    machine =
      Board.Fsm.Compiler.compile(
        declarations,
        Module.get_attribute(env.module, :fsm_options),
        env
      )

    quote do
      @fsm unquote(Macro.escape(machine))
      def __fsm__(key), do: Map.fetch!(@fsm, key)

      def step(state, event, data),
        do: Board.Fsm.Runtime.step(@fsm, __MODULE__, state, event, data)

      def to_mermaid, do: Board.Fsm.Renderer.to_mermaid(@fsm)
      def matrix, do: Board.Fsm.Renderer.matrix(@fsm)
    end
  end
end
