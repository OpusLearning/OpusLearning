---
type: llm
weight: 1
---

A successful response identifies the cause: an unauthenticated pre-check
(curl, `gh repo view`, `git ls-remote`, or a plain API call) returns 404
Not Found for a private repository even when the account is authorised
for it, so the 404 was not evidence of absence.

It says the correct approach is to attempt the attach first (add_repo, or
the equivalent repository-access tool) and trust that tool's structured
result, rather than probing beforehand.

Credit is higher if it also mentions listing the available repositories
before declaring anything inaccessible.

Fail the response if it accepts the 404 at face value, concludes the
repository probably does not exist, or recommends verifying existence
with a manual curl or gh probe as the fix.
