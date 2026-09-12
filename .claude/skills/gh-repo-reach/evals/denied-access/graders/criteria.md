---
type: llm
weight: 1
---

The question asked who unblocks the error and where exactly. Judge
against that.

Pass requires both of the following:

- It identifies this as an organisation-level policy grant rather than a
  problem with the user's own GitHub authorisation, so the person who
  unblocks it is a Claude.ai organisation owner rather than the user.
- It points at the Claude.ai admin settings as the place, naming a
  claude.ai/admin-settings URL or describing the Claude.ai organisation
  admin settings clearly enough to find.

Treat these as bonus, not requirements: contrasting this with the
separate case where the user reconnects their own GitHub connection
under Claude.ai Settings then Connectors; saying to relay the tool's
stated reason rather than retry; offering to list the repositories
already available.

Fail if it sends the user to GitHub's own app installation settings or
the Anthropic Console as the primary fix, if it recommends a workaround
that bypasses the policy such as forking or copying the code, or if it
claims the assistant can change the setting itself.
