---
type: llm
weight: 1
---

A successful response identifies the missing step: after cloning an
attached repository, the session must register the clone's root
(register_repo_root, or the equivalent "tell the session where the clone
is" call) with the clone path and the same owner and repo. Without that
registration the repository's CLAUDE.md, skills and plugins are not
loaded, which is exactly the symptom described.

Partial credit if it correctly says the clone needs to be registered or
declared to the session without naming the specific call.

Fail if it attributes the symptom only to CLAUDE.md precedence, to the
file being outside the working directory with no fix beyond adding a
directory, to needing a session restart alone, or if it says nested
CLAUDE.md files are simply not supported.
