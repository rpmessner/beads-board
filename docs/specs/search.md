# Search and retrieval across repos

Status: idea, not yet specced (2026-10-18). Board draft epic `draft:search`.

## Idea

foreman indexes the house's written history across every configured repo (specs, ADRs, session reports, briefs, tickets and their notes, AGENTS.md, commit messages) and answers `foreman search "<question>"` for agents, skills and a search box in the UI, so prior decisions and past fixes reach the work that needs them.

## Uses

- `dispatch`: a brief's "Read first" gains the top relevant past reports and decisions.
- `/tight-spec`: "have we already decided anything about X?" before asking the user.
- `diagnosing-bugs`: "have we seen this failure before?"
- Ticket filing: a duplicate check.
- The board: a search box.

## Starting shape (coordinator proposal, 2026-10-18)

1. Index in foreman's Postgres, fed by the same file watcher as ticket files (fm-axu.2), extended to `docs/` and AGENTS.md; chunks split on Markdown headings, tagged with repo, path, kind and date.
2. Start lexical: Postgres full-text search with ranking and kind/repo filters, no model.
3. Measure misses on real questions from briefs and specs; add embeddings (`pgvector`, local model via Ollama or an API) only where lexical search falls short.
4. One way in: `foreman search "<question>" [--repo] [--kind spec|report|ticket] --json`, and the same query behind the UI search box.

## Questions for the spec

- What pi's existing "jev … recalls" feature covers, and whether to reuse it, feed it, or keep the two apart.
- Corpus boundaries: which repos and paths, whether code itself is in scope, and how worktree-only docs are treated.
- Embeddings later: local vs API (privacy, cost, another service to run).
- How results reach agents: automatic in briefs, or only on request.
- Freshness and size limits; what an evaluation set of real questions looks like.
