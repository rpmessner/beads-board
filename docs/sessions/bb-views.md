# bb-views: bb-c2w.13

## Changed

Initiatives now has a Fluxon button group for configured views, with search beside it. The sidebar owns project selection. The normally closed Filters section contains beads status, type, label, and the existing stale filter. Its header counts active advanced filters while closed, excluding preset criteria, project, search, and unrestricted values that do not override a preset.

`Board.Initiatives.Disclosure` owns disclosure transitions. Browser storage remembers the open state separately from query filters. `FilterRestore` retains its first-bare-route restoration rule. The browser hook stores data without owning or changing DOM.

`Board.Config.Schema` validates views. `Board.Initiatives` applies preset criteria to tickets without changing rollups. Ticket-stage presets do not match an epic merely because its derived stage has the same name. Config reload updates the buttons; removing the selected view selects the new first view. Persisted config from before this change uses the shipped presets until the next successful reload.

## Views config

`board.toml` and `board.local.toml` replace the entire views list, like columns. The first entry is the default. The shipped list is:

```toml
[[views]]
key = "open"
title = "Open"
statuses = ["open", "in_progress", "blocked", "deferred"]

[[views]]
key = "in-flight"
title = "In flight"
stages = ["dispatched", "building"]

[[views]]
key = "stale"
title = "Stale"
stale = true

[[views]]
key = "all"
title = "All"
```

Each entry requires a unique key and a title. Optional `statuses` and `stages` are lists; empty or omitted lists impose no restriction. Statuses must be known beads statuses, including `closed`. Stages must belong to `Board.Stage`, not the epic machine. `stale = true` requires a stale ticket; false or omitted imposes no stale restriction. Criteria combine with AND. Empty view lists, malformed entries, duplicates, and invented names are rejected. Rejected reloads retain the last good config and its load timestamp.

## URL and memory contract

- A bare initial URL uses the first view, unless browser memory restores previous filters.
- An explicit query wins over browser memory, including explicit clearing.
- `view=<key>` selects a configured preset. Unknown keys fall back to the first view.
- Old URLs without `view` retain their previous unscoped behavior. `view=` preserves this custom state through later patches and storage.
- Explicit status and stale values override the corresponding preset criterion. Empty values use the preset. `status=all` and `stale=false` explicitly remove those restrictions.
- Clicking a view clears status and stale overrides, while retaining project, search, type, and label.
- Disclosure memory uses `board:initiative-filters-open:v1`; query memory keeps `board:initiative-filters:v1`. Both remain local to the browser profile and origin.

Browser integration facts: LiveSocket sends the disclosure boolean as a string on websocket connect. View buttons inside the form require `type="button"`; the form handles Enter through `phx-submit="filter"`.

## Verification

Failing-first tests covered missing shipped presets, incomplete view entries, selection and ticket-stage matching, disclosure and memory, legacy URL overrides, removed presets, old persisted config, and advanced counts. The count tests caught a label named `false`, a stale-disabling override, and unrestricted values that should not count. The runtime config test also exercises accepted and rejected TOML edits through `ReloadJob` and Postgres.

Browser failures caught native form submission, string-valued disclosure memory, and the old CSS width rule that wrapped search below the buttons. Those failures have regression assertions. The existing filters browser runner was adapted to the collapsed section and sidebar-only project selection.

Captured and inspected all four screenshots. Search aligns beside the buttons; active selection is distinct in both themes; the expanded controls have aligned labels and no overlap:

- [Default, light](../acceptance/bb-views/default-light.png)
- [Default, dark](../acceptance/bb-views/default-dark.png)
- [Advanced, light](../acceptance/bb-views/advanced-light.png)
- [Advanced, dark](../acceptance/bb-views/advanced-dark.png)

## Review scope

Sequential self-review against `dbaa1ad9158cbf6601e80eb2b3a4d56e43597f70`. That ref is HEAD, so the committed three-dot diff and commit list are empty. The requested review covered the working-tree diff and new browser runner. No subagents were used.

## Standards

Ready. Disclosure uses `Board.Fsm.step/3`; view values are validated data and do not change which events are accepted. Templates use the shared input, icon, and Fluxon button components. No explanatory UI copy or new dependencies. No remaining Critical or Important findings.

Declined to judge unrelated existing Settings copy and future detail-page workflows.

## Spec

Ready. Important count findings in `Filters.advanced_count/2` are fixed and tested. The earlier browser failures are fixed: buttons no longer submit the form, disclosure survives reload and Settings return, and search sits beside the buttons. The legacy stale control remains in the advanced section so old query values remain editable. All supplied acceptance items have test or browser evidence. No remaining Critical or Important findings.

Declined to judge additional presets beyond the four shipped defaults.

## Risk

Ready. The safety fact is that presets use the existing validated config boundary, while old URLs remain unscoped unless they name a view. Config and runtime tests prove rejected edits retain the last good config. LiveView tests prove old links, explicit overrides, removed presets, and pre-views persisted config. The browser proves URL authority, Settings return, reload, history navigation, corrupt-storage recovery, and browser isolation. This reaches proof level 5 for browser behavior and level 4 for rejected config reloads.

No schema, beads reader, worker lifecycle, or write path changed. The existing filters browser checks still pass. Cheapest pre-merge check: `mix precommit`, followed by `tools/views-acceptance.cjs` for the JS boundary.

Declined to judge non-Chromium engines and cross-tab synchronization. Persistence requires working localStorage; storage access failures remain caught. No remaining Critical or Important findings.

## Final gates

All final commands exited 0 without warnings:

```text
mix precommit
Repository hygiene: no license material or operator paths detected
4 properties, 167 tests, 0 failures

BOARD_ROLE=web mix assets.build
Tailwind and esbuild completed successfully

NODE_PATH=<Playwright node_modules> node tools/views-acceptance.cjs
PASS: default/advanced light and dark screenshots; views, search,
overrides/count, Settings restore, disclosure persistence, reload,
URL precedence, back/forward, legacy links, malformed params/storage;
no page errors

BOARD_URL=http://127.0.0.1:4756 BOARD_SCREENSHOT_DIR=<temporary output> \
  NODE_PATH=<Playwright node_modules> node tools/filters-acceptance.cjs
PASS: sidebar set/clear/counts, Settings round-trip, reload, URL authority,
back/forward, bare-route restore, corrupt storage, malformed params,
browser isolation; no page errors

git diff --check
clean
```

Initial dependency compilation emitted the existing Oban unused-clause warning; final application gates did not. The browser server was web-only on port 4756. Port 4747 was untouched. Browser checks made no database or beads writes. No commits, pushes, or `bd` commands were run; the coordinator-owned brief was left unchanged.
