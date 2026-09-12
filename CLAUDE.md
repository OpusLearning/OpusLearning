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

## GitHub repo reach

`gh-repo-reach` covers giving a session access to a GitHub repository it
cannot currently see, and reading access failures correctly. It is
defined at `.claude/skills/gh-repo-reach/SKILL.md` and triggers on its
description rather than a hook, so it needs no settings changes.

Install it for every project on a machine with
`.claude/skills/gh-repo-reach/scripts/install-user-level.sh`. Build the
`.skill` file for claude.ai profile sync, which also covers cloud and web
sessions, with `.claude/skills/gh-repo-reach/scripts/package-skill.sh`.
