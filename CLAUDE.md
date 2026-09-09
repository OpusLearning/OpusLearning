# Working with James

Apply the `finish-the-work` skill in every interaction in this
repository. It is defined at `.claude/skills/finish-the-work/SKILL.md`
and is injected automatically by the hooks in `.claude/settings.json`.
If the hooks did not run, read the skill before replying.

The skill sets posture, not procedure. Use the other available skills
(documents, spreadsheets, decks, PDFs, config, code review) to do the
work, and let finish-the-work govern scope, the definition of finished
and the closing summary.

Style: UK English, direct and respectful, short paragraphs, no em dashes.

To use the skill outside this repository, run
`.claude/skills/finish-the-work/scripts/install-user-level.sh`, or save
the packaged `.skill` file to your claude.ai profile so it syncs to
every Claude Code session.

## Desktop control

The `computer-use-linux` skill at `.claude/skills/computer-use-linux`
covers controlling James's local Linux desktop: screenshots, clicks,
typing, reading app state, saved-password lookups and router admin
pages. It only works in a local session with the MCP server registered.
From Claude Code on the web, say so and give the local command rather
than improvising. Install locally with
`.claude/skills/computer-use-linux/scripts/install-user-level.sh`.
