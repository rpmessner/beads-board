# bb-filters: bb-c2w.12

## Changed

- `Board.Initiatives.Filters` validates project, type, label, status, stale, and search query values without converting input to atoms.
- `InitiativesLive.handle_params/3` owns the filters. Form changes patch a complete query string, including empty values for explicit clearing.
- Sidebar project links patch the current filters on Initiatives. Clicking the selected project clears it without changing other filters. Links from Settings navigate to an explicit project URL.
- The shared sidebar uses `bb-nav-active` for the selected project, retains counts, and now appears on Settings too. The existing project select remains available.
- Initial streams are populated only after URL filters are resolved.

## Browser persistence

`assets/js/initiative_filters.js` stores normalized filters under `board:initiative-filters:v1` in localStorage. The hook reads its data attribute and does not own or mutate DOM. LiveSocket's params function reads storage for each join, including navigation back from Settings.

`Board.Initiatives.FilterRestore` declares the one-time restoration lifecycle. On the first bare route, remembered filters seed the query and replace the URL. Any explicit query wins, including `?project=`. Later parameter changes use the URL without restoring memory again. Invalid stored JSON or values fall back to defaults. Storage access failures in the filter adapter are caught.

Persistence is per browser profile and origin, not per user account or tab. Changing ports uses separate storage.

## Verification

LiveView tests cover URL controls and encoded patch output, invalid and nested params, restoration after Settings, explicit clearing over remembered filters, subsequent bare patches, project toggle/highlight/counts, Settings project navigation, and initial filtered stream contents.

Failing-first evidence from `mix test test/board_web/live/initiatives_live_test.exs`:

- URL slice failed on the selected type assertion, then passed after `handle_params` and patch support.
- Restoration slice failed because there was no restored patch. Mount-time patches are consumed by the LiveView test mount, so the final test asserts restored controls instead. Browser acceptance checks the resulting URL.
- Sidebar slice failed on the missing project link in both views, then passed.
- Initial URL exclusion failed because `[data-bead=e]` remained in a filtered stream, then passed after stream initialization moved out of mount.

The browser runner is `tools/filters-acceptance.cjs`. It uses Playwright from `NODE_PATH` and defaults to a web-only server on port 4754. It checks Settings round-trip, reload, explicit URL precedence, browser back/forward, bare-route restoration, malformed params, corrupt storage, browser isolation, counts, and zero page errors. It makes no database or beads writes.

Captured and inspected on the final implementation:

- [Filtered Initiatives, light](../acceptance/bb-filters/initiatives-light.png)
- [Filtered Initiatives, dark](../acceptance/bb-filters/initiatives-dark.png)

Both show beads-board selected, one matching epic, preserved sidebar counts, and the same active treatment as the Initiatives navigation item. No overlapping content or unwanted rows remain.

## Review scope

Reviewed sequentially in this session against `c83890d945fca3279d224f834e3444c103c969bb`. This ref is HEAD, so the committed three-dot diff and commit list are empty. The requested self-review covered the working-tree diff and new implementation/test files. The coordinator-owned brief was not changed. No subagents, bd commands, commits, or pushes.

## Standards

Important finding fixed: `InitiativesLive.handle_params/3` initially used a nullable assign as a one-time restoration gate. `Board.Initiatives.FilterRestore` now declares the states, guard, transitions, and restore effect through `Board.Fsm`. Filter values remain validated data. Existing disclosure machines are unchanged.

The diff adds no explanatory UI copy. Inputs retain the shared components, and both themes reuse existing navigation classes. No remaining Critical or Important findings. Verdict: ready. Declined to judge: unrelated existing Settings copy and future ticket-detail workflows.

## Spec

Critical finding fixed: the first browser screenshot showed all initial epic rows despite a filtered count of one. Calling `refresh` in mount and again in `handle_params` left initial stream entries in the rendered output. Mount now loads filter options without populating streams. A failing-first LiveView test and browser row-count assertion cover the fix.

All bb-c2w.12 acceptance items in the supplied brief pass. Decision 13's filter semantics and rolled-up counts remain unchanged. No remaining Critical or Important findings. Verdict: ready. Declined to judge: future filters or pages not named in this ticket.

## Risk

The safety fact is that normalized URL filters are authoritative after the first parameter event. Browser memory can seed only the initial bare route. This reached proof level 5 through the running browser's Settings, reload, explicit-clear, back/forward, and separate-browser checks. LiveView tests also exercise a subsequent bare patch with remembered filters present.

Shared-layout checks cover both current LiveViews, including project navigation from Settings. The full suite preserves existing expansion, reconciliation, stages, and rollups. No schema, worker, or beads adapter changed. No open Critical or Important findings. Verdict: ready.

Declined to judge: other browser engines, cross-tab synchronization, and disabled-storage behavior of the pre-existing theme code. The filter adapter tolerates unavailable storage, but persistence requires working browser storage. The cheapest pre-merge gate is `mix precommit`; the browser runner covers the JS integration it cannot test.

## Final gates

All commands exited 0 on the final implementation:

```text
mix precommit
Repository hygiene: no license material or operator paths detected
4 properties, 157 tests, 0 failures

BOARD_ROLE=web mix assets.build
Tailwind and esbuild completed successfully

NODE_PATH=<Playwright node_modules> node tools/filters-acceptance.cjs
PASS: sidebar set/clear/counts, Settings round-trip, reload, URL authority,
back/forward, bare-route restore, corrupt storage, malformed params,
browser isolation, light/dark screenshots; no page errors

git diff --check
clean
```

Fresh dependency compilation emitted the existing Oban unused-clause warning. The final application gates above emitted no warnings. The temporary web-only server used port 4754; port 4747 was untouched. No ticket status was changed here.
