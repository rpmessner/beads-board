# fm-docs: fm-c2w.18

Implemented and verified. No commits, pushes, bd commands or subagents. The installed port-4747 service, configuration and database were not touched.

## What changed

- `Foreman.Documents` lists project documents and performs bounded, read-only file access.
- `Foreman.Markdown` uses pinned MDEx 0.11.5 for GFM, including task lists, tables, footnotes, autolinks and code highlighting. Raw HTML is omitted.
- `/documents/:repo` has a streamed file list, URL-driven selection and a `Foreman.Fsm` viewer machine. Each sidebar project has a Documents control. The list sits beside the document on desktop and above it on mobile.
- Brief, report and spec paths in stage history and draft epics open in the viewer. Ticket Description, Acceptance, Design, Beads notes and Agent notes use the same renderer.
- GitHub light and dark highlighting follows the app theme without duplicating the document. Tables and code scroll within the document at narrow widths.

## Path rules

The configured project folder is the default root. The list includes `README.md`, `AGENTS.md` and all regular `.md` files beneath `docs/`, including deeply nested files. Direct links can open other `.md` files inside the root.

Every read checks containment, all filesystem components with `lstat`, the regular-file type, a bounded 1 MiB read and UTF-8 validity. Traversal outside the root, non-Markdown files, directories and symlinks are refused. This conservatively refuses internal symlinks too. Oversized documents are unavailable rather than truncated. Ticket Markdown has the same 1 MiB input limit.

Registered Git worktrees belong to the project. An existing worktree path reads that worktree's document. If its directory is gone, the reader uses the same relative path in the configured checkout. Git keeps these registrations until pruning.

After pruning, an exact absolute path already recorded in this project's stage history or draft epic can still fall back. The reader finds the longest matching listed relative document and requires the old root to be absent. It reads only the configured checkout. An unknown outside path cannot use this fallback. A missing historical path with no matching main-checkout document stays unavailable.

Relative Markdown links remain in the viewer, retain fragments and resolve against the current document. Relative traversal beyond the project root, including encoded traversal, is rejected. HTTP, HTTPS and mailto links remain external. Other protocols and non-Markdown local links are disabled.

## MDEx notes

Read the pinned [safety guide](https://github.com/leandrocp/mdex/blob/v0.11.5/guides/safety.md), [document options](https://github.com/leandrocp/mdex/blob/v0.11.5/lib/mdex/document.ex) and [highlighting example](https://github.com/leandrocp/mdex/blob/v0.11.5/examples/syntax_highlight.livemd) before implementation.

`unsafe: false` omits raw HTML rather than allowing it and then sanitizing it. This preserves renderer-generated disabled checkboxes and highlighting styles without admitting source HTML. Unsafe link protocols are also rejected before rendering.

The locked Lumis 0.10.3 output used `--athl` despite documentation describing `--lumis` as the default. The renderer sets `css_variable_prefix: "--lumis"` explicitly. Tests and browser checks verify the actual light and dark colors. MDEx and its three missing transitive packages are the only lockfile additions.

## Review baseline

`fb24954220996328ae5e8f5f94450984c1a53757` is HEAD. The three-dot diff and commit list are empty. The requested review therefore covers this session's working-tree diff and new files, excluding the coordinator brief. Axes ran sequentially in this session.

## Standards

Reviewed first against the root/app instructions and house baseline. `Documents.Viewer` declares empty, ready and unavailable states. Transitions go through `Foreman.Fsm`; selection is URL data. Collections use streams, and existing ticket/history streams remain intact. On-screen copy is labels, status and controls. Shared human timestamps are unchanged.

No Critical or Important standards findings. Browser polish findings fixed:

- Narrow table headers broke inside words. Cells now have a minimum width, and tables scroll internally.
- The new document icon compressed the project count link. The link now grows within its row. Project-dot color selectors follow the new wrapper, preserving the existing color order.
- A long path broke its extension across lines. The desktop file list is wider, with full-path titles.
- The first full-page capture placed the sticky file list mid-page because the runner scrolled to the long article's center. Full-page captures now start at the top; separate detail captures show the document content.

Declined: redesigning the existing mobile navigation and ticket workflow controls. Verdict: Ready. No open Critical or Important findings.

## Spec

Reviewed second against all six fm-c2w.18 acceptance items.

Important findings fixed with failing regressions:

- Git's worktree list does not retain pruned registrations. Added the exact-history-reference fallback and a LiveView regression. Unknown outside paths remain unavailable. The final browser fixture deletes and prunes its worktree before opening the report.
- A 32-directory listing cutoff contradicted "every .md under docs/". A 34-directory regression failed before removal of the cutoff. Symlink directories remain excluded.

Evidence covers GFM and both highlighting themes, the per-project file list, history and draft links, ticket checkboxes, traversal and symlink refusal, and relative document navigation. The browser matrix covers 390 and 1440 px in light and dark themes.

Declined: editing documents, attachments and non-Markdown downloads. Verdict: Ready. No open Critical or Important findings.

## Risk

Reviewed third for traversal, symlinks, HTML injection, large files and existing ticket-sheet behavior.

The safety boundary is the reader, not the file list or rewritten URL. Real-file tests verify that outside bytes cannot pass its static path checks. A mutation that removed `regular_path/1` failed on `docs/leak.md`, returning the planted secret. The mutation was removed and the suite passed. This is proof level 4. The running browser also verifies removed-worktree reports and viewer navigation, level 5.

Important findings fixed with failing regressions:

- Relative links normalized against `/` silently clamped `../../README.md` to the project README. A sentinel-root check now rejects escapes, including percent-encoded traversal.
- File reads were bounded, but ticket text could send unlimited input to MDEx. The shared renderer now refuses input above 1 MiB before parsing.

Raw HTML and unsafe link protocols do not reach the output. Checkbox markup and highlighting styles come from MDEx/Lumis. The schema, ticket projection and write APIs are unchanged. The full existing suite passes.

Residual boundary: this is an operator-owned local filesystem reader, not a sandbox against a hostile process swapping directory entries between `lstat` and open. Static symlinks, including intermediate directories, are refused. No adversarial concurrent-writer or network-filesystem isolation claim is made.

Declined: deployment, other browser engines, sandboxing same-user processes and modifying Git metadata. The cheapest integration check is `mix precommit`, followed by the scratch browser runner. Verdict: Ready. No open Critical or Important findings.

## Test evidence

Observed failing-first assertions for the initial read seam, outside-path refusal, worktree fallback, GFM output, relative links, viewer rendering, ticket Markdown and artifact links. Review regressions also failed before their fixes. Focused document, Markdown and viewer tests passed with 11 tests and no failures. The final full suite includes those tests.

The first browser attempt used a nonexistent Fluxon `data-state` selector. It timed out before a product assertion. The runner now waits for the visible dialog and completed animation, following the existing tabs runner. All subsequent matrix runs passed.

Scratch setup uses port 4781, database `foreman_docs_acceptance_fm-docs`, disabled workers and a newly initialized temporary Git repo. Unit tests use `foreman_test_fm-docs`. The browser fixture includes a long release spec, a table, highlighted code, footnotes, linked documents and a ticket with checked and unchecked acceptance items.

Reproduction commands:

```sh
MIX_ENV=test mix assets.build
MIX_ENV=test PORT=4781 mix run --no-start --no-halt tools/docs-acceptance.exs
# With Playwright available through NODE_PATH:
node tools/docs-acceptance.cjs
```

## Screenshots

The original twelve captures were refreshed during the correction below. Sixteen current captures are in [docs acceptance](../acceptance/fm-docs/). I opened and inspected the document and ticket views across both themes and both widths, plus the long-page layout. After widening the file list, I reran the matrix and inspected the changed desktop layout. Text and controls do not overlap. Narrow tables and code scroll internally without page overflow.

| View | 390 light | 390 dark | 1440 light | 1440 dark |
| --- | --- | --- | --- | --- |
| Document detail | [Image](../acceptance/fm-docs/document-detail-390-light.png) | [Image](../acceptance/fm-docs/document-detail-390-dark.png) | [Image](../acceptance/fm-docs/document-detail-1440-light.png) | [Image](../acceptance/fm-docs/document-detail-1440-dark.png) |
| Ticket | [Image](../acceptance/fm-docs/ticket-390-light.png) | [Image](../acceptance/fm-docs/ticket-390-dark.png) | [Image](../acceptance/fm-docs/ticket-1440-light.png) | [Image](../acceptance/fm-docs/ticket-1440-dark.png) |

Current `documents-{width}-{theme}.png` captures show the top viewport. Detail captures show the table and code, and `*-scrolled-390-{theme}.png` captures show their right edges. The correction below explains the switch from full-page screenshots.

## Final gates

```text
$ mix precommit
Repository hygiene: no license material or operator paths detected
Running ExUnit with seed: 300444, max_cases: 16
Generated escript foreman with MIX_ENV=test
Finished in 46.2 seconds (2.6s async, 43.6s sync)
5 properties, 407 tests, 0 failures
exit 0

$ MIX_ENV=test mix assets.build
Tailwind and esbuild completed successfully
exit 0

$ node tools/docs-acceptance.cjs
PASS: documents and tickets, 390/1440 × light/dark; theme colors,
relative navigation/back, removed-worktree report and draft spec;
no page errors.
exit 0
```

Gate transcripts are beside the screenshots. Initial dependency compilation emitted the previously documented upstream Oban unused-clause warning. Final application compilation, precommit and asset builds emitted no warnings.

`git diff --check` passed. The scratch server was stopped after verification.

Not verified: deployment, other browser engines and hostile concurrent filesystem mutation. No product work is deferred within the stated local-filesystem boundary. The coordinator owns ticket closure.

## Coordinator correction: ticket hierarchy and narrow scrolling

This section supersedes the earlier UI acceptance and final gate. Both coordinator findings are resolved.

Ticket Markdown inherited the document heading scale. A `# Release boundary` fixture reproduced a 25.2px h1 beneath DESCRIPTION. The browser regression failed against a 16px maximum. `assets/css/app.css` now scopes h1 through h3 to 15px subheadings inside `#ticket-sheet`, with compact spacing and no document-style divider. Document headings keep their original sizes. The runner checks all three ticket heading levels against the sheet title and verifies that the document h1 remains at least 24px.

The original tables and code blocks already accepted horizontal scrolling, but the screenshots concealed that fact and the verifier never tested it. A baseline browser probe moved the document table 62px and code 82px without page overflow. Chromium's headless `--hide-scrollbars` default hid the scrollbars in captures. Full-page capture also failed to show them reliably. The runner now disables that flag and takes viewport captures at the page top, document detail and horizontally scrolled right edge.

The Markdown boxes now have explicit width constraints, contained horizontal scrolling and visible 10px scrollbars. A browser assertion failed before the scrollbar styling. At 390px, the runner verifies both document and ticket views with a wide table and code block:

- `document.scrollingElement.scrollWidth <= innerWidth`.
- Each box stays inside the viewport while its content is wider than the box.
- Setting `scrollLeft` moves the content and reaches the right edge.
- A real 10px scrollbar gutter is present, rather than only a computed pseudo-element style.

The final light and dark runs measured these same local scroll distances:

| Box | Visible width | Content width | Scroll distance |
| --- | ---: | ---: | ---: |
| Document table | 293px | 370px | 77px |
| Document code | 291px | 388px | 97px |
| Ticket table | 327px | 370px | 43px |
| Ticket code | 325px | 381px | 56px |

All sixteen screenshots were regenerated. I inspected both themes at 390 and 1440px, including the right-edge captures. The narrow screenshots show visible scrollbar thumbs; scrolling exposes the complete Owner column and code endings. Ticket headings remain subordinate to the title. Document headings retain their full scale.

Additional evidence: [document right edge, dark](../acceptance/fm-docs/document-scrolled-390-dark.png), [document right edge, light](../acceptance/fm-docs/document-scrolled-390-light.png), [ticket right edge, dark](../acceptance/fm-docs/ticket-scrolled-390-dark.png), [ticket right edge, light](../acceptance/fm-docs/ticket-scrolled-390-light.png).

Follow-up review ran Standards, then Spec, then Risk. Standards: the heading override is scoped to the ticket sheet; no state or UI copy was added. Spec: both requested fixes have browser assertions across the full matrix. Risk: the parser, file-access rules and HTML-safety settings are unchanged, and the document heading-size check prevents accidental global shrinking. No open Critical or Important findings.

Lesson: I accepted the document typography inside ticket sections and treated no page overflow as proof that clipped content was discoverable. Prevention uses scoped CSS and executable browser checks for hierarchy, actual scrolling and visible gutters. This is structural prevention, rung 1, backed by regression gates. No lesson bead was created because this session prohibits bd commands.

### Correction final gates

```text
$ mix precommit
Repository hygiene: no license material or operator paths detected
Running ExUnit with seed: 680060, max_cases: 16
Generated escript foreman with MIX_ENV=test
Finished in 45.7 seconds (3.0s async, 42.6s sync)
5 properties, 407 tests, 0 failures
exit 0

$ MIX_ENV=test mix assets.build
Tailwind and esbuild completed successfully
exit 0

$ node tools/docs-acceptance.cjs
PASS: documents and tickets, 390/1440 × light/dark;
scoped ticket headings, unchanged document headings, no page overflow,
visible local scrolling to the right edge at 390px;
theme colors, relative navigation/back, removed-worktree report and draft spec;
no page errors.
exit 0

$ git diff --check
exit 0
```

The gate transcripts beside the screenshots contain these fresh results. No warnings in the final gates. The scratch port-4781 server was stopped after verification. No commits, pushes, bd commands, subagents or installed-service changes.
