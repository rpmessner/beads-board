defmodule Foreman.FsmDeclarationsTest do
  use ExUnit.Case, async: true

  @base """
  initial :idle
  state :idle
  event :go
  transition :go, from: :idle, to: :stay
  """
  @cases [
    {"bare effect", String.replace(@base, "to: :stay", "to: :stay, do: [:emit]"),
     "fsm: effects must be a keyword list of {name, argument} tuples"},
    {"malformed entry", String.replace(@base, "state :idle", "state :idle, enter: :emit"),
     "fsm: effects must be a keyword list of {name, argument} tuples"},
    {"unknown option", String.replace(@base, "to: :stay", "to: :stay, gaurd: :ready?"),
     "fsm: unknown transition option :gaurd"},
    {"event source", String.replace(@base, "event :go", "event :go, source: :observe"),
     "fsm: event source must be :claimed or :observed"},
    {"reserved state", String.replace(@base, ":idle", ":any"), "fsm: invalid state name :any"},
    {"nil event", String.replace(@base, ":go", "nil"), "fsm: invalid event name nil"},
    {"state group collision", @base <> "group :idle, [:idle]",
     "fsm: group :idle conflicts with a state"},
    {"empty group", @base <> "group :g, []",
     "fsm: group requires a non-empty list of state names"},
    {"empty selector", String.replace(@base, "from: :idle", "from: []"),
     "fsm: selector requires a non-empty list of names"},
    {"duplicate option", String.replace(@base, "to: :stay", "to: :stay, to: :idle"),
     "fsm: duplicate transition option :to"}
  ]
  for {{label, body, message}, index} <- Enum.with_index(@cases) do
    test label do
      module = Module.concat(__MODULE__, "Fixture#{unquote(index)}")

      error =
        assert_raise CompileError, fn ->
          Code.compile_string(
            "defmodule #{inspect(module)} do\nuse Foreman.Fsm\n#{unquote(body)}\nend",
            "declaration.exs"
          )
        end

      assert error.description == unquote(message)
    end
  end
end
