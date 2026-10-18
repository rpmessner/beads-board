# GitHub read fixtures

Captured with read-only `gh api graphql` calls to `rpmessner/form-engine` on 2026-10-18.

- `form-engine.json` contains the two open PRs, #5 and #6, with the default branch, head/base, draft, mergeability, and check rollup.
- `form-engine-tracked.json` contains the same open query and the `pr3: pullRequest(number:3)` alias. PR #3 was already merged before this session.

The query fields match `Board.Forge.GitHub`. Responses contain no authentication headers or tokens. Negative tests modify these responses in memory to exercise pagination, missing identities, and API errors. No GitHub mutation was used to produce a fixture.
