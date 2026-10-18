# Live open-PR response

`create.json` records the authorized worker-created PR #4 in `rpmessner/beads-board-scratch` on 2026-10-18. The request contains the exact approved head, base, title and body. The response retains only the status, number, URL, title, body, and head/base ref and SHA.

The transport never records headers or credentials. Both forge adapters replay this fixture in `test/foreman/forge_contract_test.exs`. Negative responses remain synthetic. Full run evidence is in `docs/acceptance/fm-openpr/`.
