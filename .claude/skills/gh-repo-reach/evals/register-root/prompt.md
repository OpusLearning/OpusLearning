---
max_turns: 8
runs: 2
allowed_tools: [Read, Glob, Grep, Skill]
---

In a Claude Code web session I got Claude to attach a second repository
and clone it into the workspace. It can read the files fine, but it keeps
ignoring that repo's own CLAUDE.md conventions and never picks up the
skills defined in it. Why?
