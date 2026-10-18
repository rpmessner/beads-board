# bb-init: bb-c2w.5

Implemented and verified, including the coordinator's three screenshot corrections. `mix precommit` passes with 4 properties, 147 tests, and no failures. No commits, pushes, bd write commands, subagents, home-config edits, or edits to other repositories. The coordinator still owns ticket closure.

## Changed

- Moved the epic fixture into `lib/board/epic.ex` as `Board.Epic`. Stage and Epic retain Decisions 7 and 8. Their generated documentation matches the goldens. The new Disclosure machine has its own golden.
- Added `Board.Overlay` and one additive migration. `apply_event/3` runs the machine and persists its effects in a transaction. Projection sync backfills first-seen entities and observes subsequent status changes.
- Added `Board.Initiatives.snapshot/1` and the pure `Board.Initiatives.Tree.build/2` query. `/` now renders Initiatives. `/settings` remains Settings.
- Fixed light-mode active navigation, wrapped the read-only TOML preview, humanized relative times, and removed the requested explanatory copy.
- Added reproducible read-only export comparison and browser acceptance scripts under `tools/`.

## Overlay contract

All workflow identities are `{repo_key, bead_id}`. No overlay table references the projection. Dropping `bead_repos` and its cascading `beads` rows leaves workflow facts intact.

| Table | Stored facts |
| --- | --- |
| `tickets`, retained from ticket 4 | Stable key, ticket stage, stage-change timestamp, lock version, orphan timestamp. |
| `epics` | Stable key, optional `beads_epic_id`, draft title/spec link, tracked epic stage, stage-change timestamp, lock version, orphan timestamp. |
| `stage_events` | Stable key, machine, event, payload, source, actor, from/to stages, outcome, ordered effects, timestamp. Invalid machine claims are recorded. |
| `overlay_effects` | Event reference plus kind/name/payload receipts for every non-notification effect, including commits, merges, flags, and close suggestions. |
| `sessions` | Per-ticket dispatch attempts with window, JSON details, started/last-seen/ended timestamps. Redispatch ends the preceding attempt. Details retain branch, harness, model, workdir, brief, report and other supplied fields. |
| `agent_notes` | Event reference, stable ticket key, actor, kind, body, timestamp. Progress/report/finding effects also update the current session heartbeat. |
| `overlay_cr_links` | Unique ticket key and CR number, used by the machine's other-open-CR guard. This is the overlay relation, not the later forge cache. |
| `epic_links` | Ticket repo/id and epic repo/id for cross-repo membership. Empty in acceptance; no links were seeded. The CLI writer belongs to .7. |

`apply_event(key, event_or_payload_tuple, %{actor: actor})` returns `{:ok, %{stage: stage, effects: effects}}` or an error. Out-of-order claims return `{:error, %{stage: stage, allowed: events}}`. The machine supplies the event source. A missing entity returns `:not_found`; `create` can initialize a `draft:<slug>`. Payload errors such as a missing dispatch window roll back the transaction.

A repo-scoped Postgres advisory lock serializes backfill, draft linking, and events. Existing entity rows also lock with `FOR UPDATE`. Event insertion, stage/version changes, and effect receipts/materializations share that transaction. Postgres NOTIFY runs in the same transaction and delivers only after the outermost commit. Rollback sends nothing. Views also reconcile every three seconds.

Draft linking keeps the slug as its canonical identity. When the reader saw the target epic first, linking merges the duplicate entity row but never rewrites its old events. `history/1` includes both identities. A closed target applies `bead_epic_closed` through Board.Epic, so linking cannot reopen it.

Backfill maps closed tickets to `done`, other ticket statuses to `queued`, and beads epics to `done` or `ticketed`. It records a `backfill` event once. Epics do not receive ticket rows. Rebuilding the projection does not reset existing stages. Missing projected entities retain their overlay with `orphaned_at`; reappearance clears the marker.

## Epic tree rules

- Parent-child reachability follows any depth. Board-side links participate in that same traversal, including across repos.
- Discovered-from reaches anything already under an epic, including other fallout. Discovery and its descendants take precedence over planned membership within that epic.
- Each epic counts each non-epic ticket once. Sub-epics are containers, not extra tickets in the denominator. Parent counts include the whole subtree.
- A sub-epic appears under its nearest planned epic ancestor. Expansion is independent per row. Parent expansion does not duplicate the tickets owned by a displayed sub-epic.
- A ticket is an orphan only if it belongs to no epic and has neither a discovered-from edge nor a board-side link. Unresolved discovery links are not silently relabelled as orphans.
- Visited sets bound cyclic graphs. Malformed epic cycles stay visible rather than disappearing.
- Empty ticketed epics stay `ticketed`. All closed children mean `shipped`; all open children committed or later mean `shipping`; any child past queued means `building`. A tracked `done` epic stays `done`, even with open fallout.
- Filters retain full progress/histogram totals while filtering visible tickets and relevant initiatives. Unplanned is collapsed initially and opens per project. Histogram bins follow configured ticket-stage columns.
- All bead-ID lists use `Board.Beads.Id.sort_key/1`: numeric runs compare as integers at every depth, with the original ID as a deterministic tie-breaker. This covers projection results, drafts, epics/sub-epics, planned work, fallout, orphans and ancestor tie-breaks.
- Drafts remain first; active epics sort building → shipping → ticketed, then naturally within each stage and repo. Top-level done/shipped epics occupy a counted, initially collapsed Done group immediately above Unplanned. Completed sub-epics stay under their parents to preserve hierarchy and roll-ups. Finished unlinked drafts also move into Done.
- An epic with no tickets shows only a dash in Progress: no count, percentage or progress bar.

## Acceptance and screenshots

The independent verifier reads fresh real exports through the existing guarded command adapter. It computes membership from those responses and compares it to the running query. The [evidence JSON](../acceptance/bb-init/evidence.json) records:

| Epic | Stage | Closed / total | Fallout |
| --- | --- | --- | --- |
| fe-813 | building | 5 / 10 | none in today's source |
| fe-lwp | building | 12 / 19 | fe-lwp.15, fe-lwp.16 |
| bb-c2w | building | 4 / 11 | none |

`sk-5o2` appears in Unplanned under skills. The browser observed this build session's genuine overlay dispatch/progress move `bb-c2w.5` to building without reloading. No beads content changed. All seven real repositories had identical tracked `git status` before and after these reads.

Captured and inspected against Main/Machine and the requested polish changes:

- [Initiatives light](../acceptance/bb-init/initiatives-light.png) and [dark](../acceptance/bb-init/initiatives-dark.png).
- [Own build with children](../acceptance/bb-init/build-children.png), [fallout](../acceptance/bb-init/fallout-dark.png), and [Unplanned](../acceptance/bb-init/unplanned-dark.png).
- [Settings light](../acceptance/bb-init/settings-light.png) and [dark](../acceptance/bb-init/settings-dark.png).
- [Mobile](../acceptance/bb-init/mobile.png).
- Expanded Done in [light](../acceptance/bb-init/done-light.png) and [dark](../acceptance/bb-init/done-dark.png).

All screenshots were refreshed and inspected after the coordinator review. The real home now shows 17 active epics and 7 completed epics. `bb-c2w.1` through `.11` display numerically; `wow-you1` and empty completed epics show dash-only progress. Done is collapsed above Unplanned on initial load.

The layout retains the sidebar, compact filters, epic rows, stage badges, progress bars, histogram, fallout and CR columns, and Unplanned panel. It uses Fluxon tokens/badges in both themes. Project filtering is a select rather than the mockup's chip row. Real data has no draft epics, so screenshots do not fabricate drafts; LiveView tests cover their top placement. CRs display an unavailable placeholder until .8.

The first mobile capture exposed overlapping orphan text and badges. The final capture uses a stacked ticket grid and has no page-wide overflow at 390px. The TOML preview wraps at whitespace or within long paths rather than splitting ordinary words. Both active sidebar states are visible in light mode. Snapshot ages use minutes/hours. The removed taglines/help paragraphs are absent.

## Verification trail

- Backfill, invalid claims/effects, draft creation, projection closure/reopening and the pure tree failed against stubs or the preceding behavior before implementation.
- Spec regressions for closed-target draft linking and explicit self-transition audit outcomes failed, then passed.
- The stale epic badge test failed before the aggregate badge fix. A LiveView test also verifies that a persisted cross-repo board link changes the epic's count and expanded tickets without adding a beads edge.
- `overlay_commit_test.exs` exercises real committed transactions outside the SQL sandbox wrapper. Concurrent identical dispatches produce one accepted event and one logged invalid event.
- An in-memory mutation that replaced overlay notification with a no-op caused the committed-notification test to fail with an empty mailbox. The checkout was never mutated by this probe. The restored application passes.
- `tools/initiatives-acceptance.cjs` passes real progress checks, live events, fallout/orphan expansion, themes, Settings overflow/age/navigation checks, mobile width, and zero page errors.

The temporary config lives under `/tmp/bb-init`, not the user's config directory. It names real repos for guarded read-only acceptance. The development database now contains their projection and this session's overlay events. No worker loop was started against them; sync ran explicitly through SyncJob. The temporary web process is stopped at handoff. After screenshots, `bb-c2w.5` received its genuine `report` event with this report path and is now `reported` in the overlay.

## Review scope

Baseline `8239605a7646da3b214cb8198814748685eaa16a` resolves to HEAD; the committed three-dot diff is empty. The explicitly requested self-review covers the working-tree diff and new files. No commits, pushes, beads commands in this worktree, or subagents. The coordinator-owned brief is excluded.

## Standards

Reviewed first against local/root AGENTS and the house baseline. Stage and epic workflows use Board.Fsm; disclosures use the new two-state Disclosure machine. Tree reachability, derived stages, filtering and timestamp formatting are pure computation, not duplicate tracked lifecycles. Filters change data, not accepted UI events.

- Important, fixed at `lib/board_web/live/initiatives_live.ex:171`: initial browser capture showed unstyled core input defaults (the generated component still names absent daisyUI classes). Initiatives now supplies fully styled input classes and a switch, without adding daisyUI.
- Testing-order limitation: backfill, apply-event and projection integration have observed red-first assertions; the LiveView render body preceded its home-route tests. Those tests failed against the old home before routing changed. This is not a complete TDD trail; no claim otherwise.
- Minor: broad tree cases were written together rather than one assertion slice at a time. They failed against the empty tree and now exercise the real pure implementation.

Declined: later ticket sheet, stage-column epic detail, forge panel and agent HTTP/CLI behavior belong to subsequent tickets. No remaining Critical/Important standards implementation finding at this review boundary; the final browser and precommit gates below pass.

## Spec

Reviewed second against bb-c2w.5 (including its 2026-10-17 note), Decisions 7/8/13 and acceptance 2b.

- Important, fixed at `lib/board/overlay.ex:368`: linking a draft after the reader had already backfilled its beads epic rewrote prior event identities and discarded a closed target's state. A failing regression now preserves the old append-only events, queries both identities, and applies the observed closure through Board.Epic after linking.
- Important, fixed at `lib/board/overlay.ex:202`: an explicit epic `done` → `done` transition was labelled ignored because it had no effects. Audit outcome now follows the machine's selected row kind, not inferred state equality. Regression failed then passed.
- Home is Initiatives; draft ordering, nested epics, full-tree progress, fallout precedence, cross-repo link membership, collapsed per-project Unplanned and filters are implemented. Full totals do not shrink when filtering visible children. CRs are explicitly unavailable (`—`), not a fabricated zero.
- The real guarded-export comparison passes: fe-813 building 5/10; fe-lwp building 12/19 with fe-lwp.15 and fe-lwp.16 as fallout; bb-c2w building 4/11. The literal fe-813-fallout example in spec 2b is absent in today's source. No edge was invented or written; the ticket's acceptance wording (a discovered-from ticket under its epic) is checked against fe-lwp.

Declined: creation of real beads links to manufacture the historical example, later epic stage-columns/detail sheet, and open CR data before ticket .8. Verdict: ready, with the historical data difference above recorded. No open Critical/Important implementation finding.

## Risk

Reviewed third. The safety fact is that all workflow writes serialize and commit independently of the droppable projection. Proof level 4 comes from `overlay_test.exs`, `overlay_commit_test.exs`, and the projection rebuild tests. Proof level 5 comes from the running browser receiving this build's overlay progress without a reload.

Cleared risks:

- Projection replacement/deletion retains stages and history. Hash-identical exports still make no database writes in the SQL-telemetry regression.
- Concurrent identical claims cannot both apply. The committed concurrency test produces exactly one accepted event and one invalid history row.
- Subscribers cannot see rolled-back stage/effect changes. The committed notification test checks no delivery inside the outer transaction or after rollback, then receives the committed invalidation. The no-notify mutation makes that test fail.
- The overlay uses no projection foreign keys. The new board link relation remains empty in real acceptance.
- Store access still uses the unchanged guardian, passive lock check and SyncJob admission. Every real repo's tracked status is unchanged.

Important findings fixed during this axis:

- `lib/board_web/live/initiatives_live.ex:77` filtered on descendant staleness but omitted the epic's aggregate stale badge. The failing LiveView assertion now passes.
- `lib/board_web/live/initiatives_live.ex:392`: the mobile screenshot exposed overlapping ticket metadata, despite no document-wide overflow. The responsive ticket grid fixes the visible failure; the replacement screenshot was inspected.

Residual limits: LISTEN/NOTIFY is transient, with initial fetch and three-second reconciliation as recovery. No day-long endurance or another ten-minute writer probe ran; this change does not alter the store reader. The future API must reject externally submitted observed events. This context intentionally accepts trusted observed calls. The later forge adapter must populate the CR relation through events, not bypass stage locking.

Declined: HTTP authentication/offline replay, forge jobs, systemd deployment, and destructive migration rollback against authoritative production data. These are not this ticket's claims. Verdict: ready within the tested boundary. The cheapest pre-merge gate is `mix precommit`.

## Coordinator screenshot corrections

The earlier visual review missed lexical child order, misleading empty progress, and completed epics mixed into active work. Prevention: assert the actual ID sequence, zero-denominator rendering, and section placement/count/collapsed state—not just row presence.

Added failing regressions for natural ordering across tree lists, dash-only empty progress, and Done grouping. Added a closure/reopening regression that moves an expanded epic and its children between Active and Done without duplicate DOM IDs. These now pass. The browser runner checks the real `.1`–`.11` sequence, empty progress, initial Done collapse/count and expanded finished rows in both themes.

A browser rerun initially failed because its anchored stage regex did not allow the badge's surrounding whitespace. A direct DOM probe isolated this to the verifier; the corrected regex and full rerun pass. No product workaround was added. This rerun sends genuine progress while `bb-c2w.5` remains `reported`; the initial acceptance above demonstrated its actual transition to building.

Sequential follow-up review:

1. **Standards:** Done uses the existing declared Disclosure machine and LiveView streams. The shared epic renderer keeps active/finished rows identical. No open Critical/Important finding.
2. **Spec:** All three coordinator corrections are covered, including natural ordering at nested numeric depths and both done/shipped membership. Full counts, fallout precedence and sub-epic hierarchy remain unchanged. No open Critical/Important finding.
3. **Risk:** No schema or stage-machine changes. Natural sorting changes read order only; unchanged-export no-write coverage still passes. Stream movement, expansion and closure/reopening have regression coverage. No open Critical/Important finding.

No lesson bead was created because this session prohibits bd writes. The prevention and evidence are recorded here for the coordinator.

## Final gates

Fresh dependency compilation reproduced the previously accepted Oban unused-clause warning and a file_system future-mtime reset. No dependency source was changed. The final application compile and gates below have no warnings.

All exit 0 on the final artifact:

```text
MIX_ENV=test mix compile --warnings-as-errors --force
  Compiling 56 files (.ex)
  Generated board app
mix precommit
  Repository hygiene: no license material or operator paths detected
  4 properties, 147 tests, 0 failures
BOARD_ROLE=web mix assets.build
  Tailwind and esbuild completed successfully
BOARD_ROLE=web mix run --no-compile tools/verify-initiatives.exs
  PASS: fe-813, fe-lwp, bb-c2w and a real orphan
automated browser acceptance
  PASS: natural child order, dash-only empty progress, collapsed Done/count,
        real progress, live overlay events, fallout, Unplanned, themes,
        Settings polish, mobile width; no page errors
git diff --check
  clean
```

Review totals: Standards has the disclosed testing-order limitation. Spec has two Important findings fixed. Risk has two Important findings fixed. No open Critical/Important implementation findings. No ticket was closed here.

Changed: the transactional overlay, epic query, Initiatives home, four initial polish fixes, and three coordinator screenshot corrections.
Verified: the tests, real guarded exports, live browser events, screenshots and gates above.
Not verified: the historical fe-813 fallout example, because that edge does not exist in today's real source; future ticket/forge/CLI/deployment features; day-long endurance.
