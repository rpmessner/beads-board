defmodule Board.FsmCompileTest do
  use ExUnit.Case, async: true

  @base """
  initial :idle
  state :idle
  event :go, source: :claimed
  ignore :go, from: :idle
  """

  @cases [
    {"missing initial", "state :idle", "fsm: exactly one initial is required (got 0)"},
    {"duplicate initial", @base <> "initial :idle",
     "fsm: exactly one initial is required (got 2)"},
    {"duplicate state", @base <> "state :idle", "fsm: duplicate state :idle"},
    {"duplicate event", @base <> "event :go", "fsm: duplicate event :go"},
    {"duplicate group", @base <> "group :g, [:idle]\ngroup :g, [:idle]",
     "fsm: duplicate group :g"},
    {"unknown initial", String.replace(@base, "initial :idle", "initial :missing"),
     "fsm: undeclared state :missing"},
    {"unknown state or group", String.replace(@base, "from: :idle", "from: :missing"),
     "fsm: undeclared state or group :missing"},
    {"unknown destination",
     String.replace(
       @base,
       "ignore :go, from: :idle",
       "transition :go, from: :idle, to: :missing"
     ), "fsm: undeclared state :missing"},
    {"unknown group member", @base <> "group :g, [:missing]", "fsm: undeclared state :missing"},
    {"unknown event", String.replace(@base, "ignore :go", "ignore :missing"),
     "fsm: undeclared event :missing"},
    {"unknown guard",
     String.replace(
       @base,
       "ignore :go, from: :idle",
       "transition :go, from: :idle, to: :stay, guard: :ready?"
     ), "fsm: undeclared guard :ready?"},
    {"unknown effect",
     String.replace(
       @base,
       "ignore :go, from: :idle",
       "transition :go, from: :idle, to: :stay, do: [emit: :go]"
     ), "fsm: undeclared effect :emit"},
    {"unknown entry effect",
     String.replace(@base, "state :idle", "state :idle, enter: [emit: :go]"),
     "fsm: undeclared effect :emit"},
    {"missing guard function", @base <> "guard :ready?",
     "fsm: guard :ready? requires public def ready?/2"},
    {"private guard function", @base <> "guard :ready?\ndefp ready?(_, _), do: true",
     "fsm: guard :ready? requires public def ready?/2"},
    {"uncovered pair", String.replace(@base, "ignore :go, from: :idle", ""),
     "fsm: no row for (:idle, :go); add a transition, ignore or invalid"},
    {"all guarded",
     String.replace(
       @base,
       "ignore :go, from: :idle",
       "guard :ready?\ndef ready?(_, _), do: true\ntransition :go, from: :idle, to: :stay, guard: :ready?"
     ), "fsm: every row for (:idle, :go) is guarded; add an unguarded fallback"},
    {"duplicate rows", @base <> "invalid :go, from: :idle",
     "fsm: duplicate rows for (:idle, :go) with equal rank and guard"},
    {"dead row", @base <> "ignore :go, from: :any",
     "fsm: dead row; earlier or more specific rows decide every pair it names"},
    {"unreachable state", @base <> "state :other\nignore :go, from: :other",
     "fsm: state :other is unreachable from :idle"},
    {"effects on ignore", String.replace(@base, "from: :idle", "from: :idle, do: [emit: :go]"),
     "fsm: ignore/invalid rows cannot have effects"},
    {"effects on invalid",
     String.replace(
       @base,
       "ignore :go, from: :idle",
       "invalid :go, from: :idle, do: [emit: :go]"
     ), "fsm: ignore/invalid rows cannot have effects"},
    {"invalid observed",
     String.replace(@base, "source: :claimed", "source: :observed")
     |> String.replace("ignore :go", "invalid :go"), "fsm: observed event :go cannot be invalid"}
  ]

  for {{label, body, message}, index} <- Enum.with_index(@cases) do
    test label do
      module = Module.concat(__MODULE__, "Fixture#{unquote(index)}")

      source =
        "defmodule #{inspect(module)} do\nuse Board.Fsm, observed_never_invalid: true\n#{unquote(body)}\nend"

      error =
        assert_raise CompileError, fn -> Code.compile_string(source, "invalid_fixture.exs") end

      assert error.description == unquote(message)
      assert error.file == "invalid_fixture.exs"
      assert error.line > 0
    end
  end
end
