---
name: computer-use-linux
description: Observe and control James's local Linux desktop through the computer-use-linux MCP server (agent-sh/computer-use-linux). Use when James asks Claude to "use the computer", control the desktop, open or drive a GUI app, take a screenshot, click, type, scroll, read what is on screen, look up a saved password in a browser, or work through a router or device admin page such as 192.168.6.1. Also use to install, register or troubleshoot the computer-use-linux server. Runs only on a local Linux desktop session, not in Claude Code on the web.
---

# computer-use-linux

`computer-use-linux` is a Rust MCP server and CLI that reads accessibility
trees (AT-SPI), takes screenshots, lists and focuses windows, and drives
clicks, scrolls and keystrokes on GNOME, KDE, Hyprland, i3, COSMIC and
generic X11. Upstream: <https://github.com/agent-sh/computer-use-linux>
(MIT). This skill adapts its runbook for Claude Code.

Related files in this skill:

- `references/tools.md`: every MCP tool with its parameters.
- `references/setup.md`: install paths, doctor blockers and fixes.
- `references/recipes.md`: worked procedures, including finding a saved
  password for a host and working through a router admin page.
- `scripts/install.sh`: installs the binary, enables AT-SPI, registers
  the MCP server in Claude Code at user scope and runs `doctor`.
- `scripts/install-user-level.sh`: copies this skill into `~/.claude`
  so it is available in every local session.

## Where this works

The server controls the desktop of the machine it runs on. It only
works when Claude Code is running locally in James's Linux desktop
session with the MCP server registered.

Check for the tools before planning any desktop work. In Claude Code
they are named `mcp__computer-use-linux__<tool>`, for example
`mcp__computer-use-linux__doctor`. If none are present:

1. In Claude Code on the web or any remote container, say plainly that
   the desktop cannot be reached from here, and give James the exact
   command to run locally instead. Do not improvise with shell
   commands, browser automation or guesses.
2. In a local session, run `scripts/install.sh` (or tell James to),
   then ask him to restart Claude Code or run `/mcp` to load the tools.

## Setup check

Before the first desktop action in a session, confirm readiness:

```bash
computer-use-linux doctor | jq .readiness
```

Ready means `can_register_mcp_tools`, `can_build_accessibility_tree`,
`can_query_windows` and `can_send_development_input` are all `true` and
`blockers` is empty. Otherwise follow `references/setup.md`. Common
fixes: `computer-use-linux setup` (AT-SPI), `computer-use-linux
setup-window-targeting` then log out and in (GNOME Wayland), and
`systemctl --user enable --now ydotoold` when doctor selects ydotool.

## Operating loop

1. Start with `get_app_state` for the target app or window. Pass
   `include_screenshot: false` when the accessibility tree is enough.
   Its readiness block flags missing setup without the full report.
2. Identify the window with `list_windows` or `focused_window` and
   confirm it by title, app id, pid or wm class before any input.
3. Prefer semantic targets: an `element_index` from `get_app_state`, or
   `role` / `name` / `text` / `states` selectors. Use coordinates only
   when the surface has no useful accessibility tree.
4. For text, use `type_text` with a window target rather than trusting
   current focus. Use `press_key` for chords such as `Ctrl+L`.
5. After every mutating action, re-observe with `get_app_state`,
   `focused_window` or a screenshot before the next step.
6. Send one desktop action at a time. Never run computer-use tools in
   parallel; input is stateful.

## Safety rules

- `click`, `drag`, `press_key`, `type_text`, `perform_action` and
  `set_value` change real application state. Ask before any step that
  would send, submit, pay, delete, overwrite, install or change a
  setting, unless James has already authorised that exact action.
- Never type a password, passphrase or one-time code. When a login,
  keyring or "reveal password" prompt appears, stop and ask James to
  type it himself, then continue.
- A password James asked you to look up belongs to him. Report it in
  the chat reply only. Never write it to a file, a commit, a log or an
  external service.
- Do not enable `run_shell` (`COMPUTER_USE_LINUX_ENABLE_SHELL=1`) for
  unattended use. Bash in Claude Code already covers shell needs.
- Distinguish what you saw from what you assume. If a screenshot or
  tree is ambiguous, say so rather than guessing.

## Reporting

Close with what was observed, what was changed, and anything left for
James to do (for example a keyring prompt or a portal dialog). Keep
screenshots out of the reply unless he asked to see them.
