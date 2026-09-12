---
type: llm
weight: 1
---

A successful response names both levers that widen reach before a session
starts: installing the Claude GitHub App on the repositories, and running
/web-setup from the terminal to send the local gh CLI token to the Claude
account.

Because the user says they use the gh CLI constantly, the response should
recommend /web-setup as the better fit, and explain that it covers any
repository the gh token can reach whether or not the app is installed.

Fail if it names neither lever, if it only tells the user to keep
attaching repositories per session, or if it invents a mechanism such as
a config file listing repositories or an environment variable of repo
names.
