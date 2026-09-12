---
name: gh-repo-reach
description: Give a Claude Code session reach to a GitHub repository it cannot currently see, and diagnose repository access failures correctly. Use when a repo is out of scope, missing from the workspace, or returns 404, "not found", "no access" or a permissions error; when work spans more than one repository; when asked which repositories are available; when setting up a cloud or web session, a routine or Claude Tag to work on a repo it was not started with. Prevents the common failure of reporting a repository as inaccessible after an unauthenticated pre-check.
---

# GitHub Repo Reach

## Purpose

A session can only work on repositories it can actually reach. Reach is
set by the surface the session runs on, not by the model. This skill
gets reach extended correctly and stops the two failure modes that waste
a session: declaring a reachable repository inaccessible, and quietly
working around a missing repository instead of attaching it.

UK English, direct, short paragraphs, no em dashes.

## Never pre-check before attaching

This is the rule that matters most. Do not run `curl github.com`,
`gh repo view`, `git ls-remote` or any other probe to test whether a
repository exists before trying to attach it.

Unauthenticated requests to a private repository return 404 Not Found
even when the repository is real and the account is authorised for it.
Acting on that 404 produces a confident, wrong "this repository does not
exist" and ends the task early.

Attach first. The attach tool performs the real reachability and
authorisation check and returns a structured result. Believe that
result, not a pre-check.

Equally, do not report a repository as unavailable before listing what
is available. List first, then say.

## Identify the surface

Reach works differently on each surface. Establish which one before
acting.

**Cloud or web session** (claude.ai/code, mobile, a routine, Claude
Tag, a GitHub Action). The container was provisioned with a fixed set
of repository sources cloned at start. Anything else needs attaching
during the session. There is no `gh` CLI; GitHub work goes through the
GitHub MCP tools.

**Local CLI session.** Reach is the filesystem plus whatever the local
`gh` and git credentials can already see. Nothing needs attaching;
directories need adding.

If unsure, check for the claude-code-remote tools and the absence of
`gh`. Their presence means a cloud session.

## Cloud session: attach a repository

1. **List what is available.** Call `list_repos` (the claude-code-remote
   MCP server), optionally with a substring query. This is the only
   honest basis for saying a repository is or is not available. Load it
   with ToolSearch if it is not already in the toolset.

2. **Attach it.** Call `add_repo` with `owner` and `repo` as separate
   fields, exactly as given. Set `access` deliberately:
   - `read` for cloning, reading and searching. For a public repository
     the session's git proxy often already serves this, and the tool
     will say so rather than attaching.
   - `push` when the session must push commits, open a pull request or
     use GitHub API tools against it. This runs the full access checks.

3. **Clone it.** The successful result includes a clone command. Run it.
   In a self-hosted runner, clone under the session's base working
   directory.

4. **Register the clone.** Call `register_repo_root` with the absolute
   clone path and the same owner and repo. Without this, the repo's
   `CLAUDE.md`, skills and plugins are not loaded on the next turn, so
   the session works on the code while ignoring its instructions. This
   only works for a repo already attached by `add_repo`.

A repository added this way is in scope immediately, even though the
session's start-of-session scope text will not mention it.

## Cloud session: when access is denied

Read the tool's own reason and relay it. Do not retry the same
repository and do not guess. The result distinguishes three cases.

**The repository genuinely does not exist or is not accessible.** Say
so plainly, having listed first.

**The repository exists but is not enabled for this workspace, project
or organisation.** A Claude.ai organisation owner grants repository
access at https://claude.ai/admin-settings/claude-tag . Point at the
settings page the tool result names, and no other URL.

**The GitHub App is not installed or the GitHub connection is not
linked.** The user reconnects their own GitHub authorisation under
claude.ai Settings then Connectors:
https://claude.ai/customize/connectors?auth_start=github&auth_start_force=1
Installing the Claude GitHub App on the repository
(https://github.com/apps/claude) is what enables private repository
access and auto-fix for its pull requests.

In every denial case, offer the useful next move: which repositories
are already in the session, and help drafting the access request. Never
invent an alternative hosting route.

## Widening reach before the session starts

Two levers change what future sessions can reach, and they are the real
fix when attaching keeps failing.

**GitHub App.** Authorised during web onboarding. Reaches any public
repository and any private repository the app is installed on. This is
the lever for teams and for pull request auto-fix.

**`/web-setup`.** Run in the local terminal, it sends the local `gh` CLI
token to the Claude account. Reach then covers any repository that token
can access, app installed or not. This is the lever for an individual
developer who already lives in `gh`. It is hidden on Team and Enterprise
plans unless an owner turns on Quick web setup at
https://claude.ai/admin-settings/claude-code , and it is unavailable to
organisations with Zero Data Retention.

For a repository with no GitHub remote, or on GitLab or Bitbucket,
`claude --cloud` bundles and uploads the local repository instead of
cloning. Set `CCR_FORCE_BUNDLE=1` to force it. The session can read and
work, but it can only push back to a GitHub remote the connection has
push access to.

## Local CLI: add a directory, not a repo

There is nothing to attach. Reach is extended by giving the session
another working directory, with `/add-dir <path>`, or by launching
Claude Code with more than one directory. Clone the second repository
first if it is not already on disk.

Authorisation is whatever local git and `gh auth status` already hold.
If a clone fails, fix the credential, do not treat it as a Claude
limitation.

## Stay inside the granted reach

Reach is a permission, not an invitation.

Read from, write to and search only the repositories in scope or
attached this session. Search and listing tools that take no repository
argument can reach further than the session's scope. Do not use them to
look outside it.

Attaching with `push` because `read` was refused is not a workaround.
If read access is denied, push will be too, and asking for the wider
grant to dodge a narrow refusal is the wrong move.

An attached repository does not extend to its forks, its organisation's
other repositories, or anything its documentation points at. Attach
those separately, on their own merits.

## Definition of finished

Reach work is finished when the repository is attached, cloned,
registered, and the first real read of its contents has succeeded. A
successful `add_repo` result is a tool report, not a verified result.
Read a file from the clone before saying the repository is available.

If reach could not be granted, finished means the user has the exact
blocker, the exact remedy URL from the tool result, and the list of
repositories that are available now. Name the owner of the unblock: an
organisation owner for a policy grant, the user for their own GitHub
connection.
