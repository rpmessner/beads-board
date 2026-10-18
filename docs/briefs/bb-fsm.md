You are a build session in beads-board (~/dev/utils/bb-fsm, a git worktree on branch `bb-fsm`). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
The house Elixir state-machine DSL, `Board.Fsm`: every stateful feature in the board is declared with it, checked at compile time, stepped by a pure function, and documented by a generated diagram and matrix. Done as a library inside the board's Phoenix project, which this ticket creates as a plain scaffold.

## Read first
- docs/spec.md (Decisions 6, 7, 8) and docs/design.md section 6 (vocabulary, the ten checks, generated output, the stage-machine prototype).
- The house principle: ~/.agents/skills/principles/references/state-machine-skeleton.md and state-machine-research.md beside it.
- form-engine's Zig kit for concepts (not syntax): ~/dev/music/form-engine/core/fsm.zig and docs/view-transport.md (a generated doc).
- ~/dev/AGENTS.md Elixir house rules.

## Tickets
bb-c2w.3. The coordinator has already claimed it; do not run bd.

## Skills
- `tdd` at these seams: the compile checks (each a fixture module that must fail to compile with its documented message, asserted by a test), step/3 against the table, the generated doc golden, and a StreamData property test (random event sequences never raise; observed events never invalid where the option is on).
- `verify-before-claiming` before writing the report.
- `code-review` on your own diff against e6cf1a0335bc077e31b80a0da4a644c1781bac25 before printing the marker: Standards and Spec axes (Spec = bb-c2w.3 acceptance and spec Decision 6), plus Risk (macro hygiene, compile-time cost, a public API every later machine uses). Run the axes one after another in this session; spawn no subagents. Fix every Critical and Important finding.

## Decisions already made
- Declarations are function-call style, not one big data structure: initial, state (enter/exit effects), group, event (source: :claimed or :observed), guard, effects, transition (from: state, group, list or :any; to: state or :stay; guard:; do: effects), ignore, invalid. Row resolution: state specificity, then event specificity, then declaration order; first row whose guard holds.
- step(state, event, data) is pure and total: {next, effects} or {:error, {:invalid, state, event}}; event is an atom or {atom, payload}; effects ordered exit, row, entry (exit/entry only on a real change).
- __fsm__/1 introspection; to_mermaid/0 and matrix/0; a mix task writes docs/machines/<name>.md; a test fails when the committed doc differs.
- No :gen_statem in the MVP. No allocation concerns; normal Elixir.
- Scaffold: `mix phx.new` into this worktree root with app name `board`, Postgres, Phoenix 1.8.7 (the installed phx_new), LiveView 1.1.31 as gw2 pins; no Fluxon, Oban or extra deps yet (ticket bb-c2w.4 adds them). StreamData as a test-only dep. Do not create or touch any database: the DSL tests must not need one (run them with a test alias that skips ecto setup, or keep the default and document that `mix test` needs Postgres running, which it is). Prove the stage machine from spec Decision 7 and the epic machine from Decision 8 compile in the DSL as test fixtures; do not wire them into the app (ticket bb-c2w.5 does).

## Rules
- No commits, no pushes, no bd commands. Stay in this worktree. Do not edit ~/.config, dotfiles or any other repo. Use /usr/bin/rm, not rm. Spawn no subagents.
- Never String.to_atom on input; zero compile warnings.

## Done when
- `mix precommit` (or the phx.new default `mix format --check-formatted`, `mix compile --warnings-as-errors`, `mix test`) green.
- Every compile check in spec Decision 6 has a failing fixture with its asserted message.
- Stage and epic machines compile as fixtures; their generated Mermaid and matrix are committed under docs/machines/ and held by the golden test.

## Report back
Write docs/sessions/bb-fsm.md: the DSL syntax with a short example, the check list with the exact compile messages, the generated stage-machine doc excerpt, review findings per axis with what you fixed and what you left open, final gate output. Then print BB-FSM DONE alone on the last line.
