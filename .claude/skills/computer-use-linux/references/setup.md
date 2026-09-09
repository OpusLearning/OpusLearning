# Setup and troubleshooting

## Quick path

From a local terminal in James's desktop session:

```bash
~/.claude/skills/computer-use-linux/scripts/install.sh
```

or from a clone of this repository:

```bash
.claude/skills/computer-use-linux/scripts/install.sh
```

The script installs the binary, enables AT-SPI, installs the GNOME Shell
extension on GNOME Wayland, enables `ydotoold` where the unit exists,
registers the MCP server with `claude mcp add --scope user`, and prints
the doctor readiness block. Flags: `--check` runs doctor only,
`--no-mcp` skips Claude Code registration, `--method npm|binary|cargo`
forces an install method.

## Install methods

| Method | Command | Needs |
| --- | --- | --- |
| npm wrapper (preferred) | `npm install -g @agent-sh/computer-use-linux` | Node.js 18+. Downloads and verifies the release binaries. |
| Prebuilt binary | see upstream README "Option D" | curl, sha256sum. Installs to `~/.local/bin`. Copy both `computer-use-linux` and `computer-use-linux-cosmic`. |
| Cargo | `cargo install computer-use-linux` | Rust toolchain. No system setup. |
| Upstream `install.sh` | `git clone https://github.com/agent-sh/computer-use-linux && cd computer-use-linux && ./install.sh` | Installs distro packages with sudo, builds from source, configures everything. Heaviest but most complete. |

System pieces the lighter methods leave to you:

```bash
sudo apt install at-spi2-core ydotool      # ydotool 1.0.3+ only if doctor selects it
sudo apt install xdotool                   # X11 sessions
sudo apt install wtype                     # optional Unicode typing on wlroots/Hyprland
computer-use-linux setup                   # GNOME AT-SPI gsettings bridge
computer-use-linux setup-window-targeting  # GNOME Shell extension, then log out and in
systemctl --user enable --now ydotoold     # only when doctor selects ydotool
```

## Register with Claude Code

```bash
claude mcp add --scope user computer-use-linux -- computer-use-linux mcp
claude mcp list
```

Use the absolute path if the binary is not on `PATH`. Inside a session
run `/mcp` to confirm the tools loaded. Scope `user` makes it available
in every project on the machine, which is what "persists across
sessions" means here.

## Reading doctor output

```bash
computer-use-linux doctor | jq .readiness
```

| Symptom | Fix |
| --- | --- |
| `accessibility.at_spi_bus.ok = false` | `computer-use-linux setup`, then restart GTK, Qt and Electron apps. |
| `windowing.can_list_windows = false` on GNOME Wayland | `computer-use-linux setup-window-targeting`, log out and in. |
| `windowing.can_list_windows = false` elsewhere | Install the compositor tool named in `doctor.windowing.backends` (`hyprctl`, `i3-msg`, `wmctrl` and `xprop`, KWin scripting). |
| Input not ready on Wayland | Needs a keyboard-capable RemoteDesktop portal or ydotool 1.0.3+ with `ydotoold` running. Socket should be at `/run/user/$UID/.ydotool_socket`. |
| Input not ready on X11 | Install `xdotool`. |
| First screenshot shows a portal dialog | Accept once and tick "remember". |
| Older ydotool rejected | Upgrade to 1.0.3 or newer; doctor refuses incompatible CLIs. |

## Environment overrides

Rarely needed. `COMPUTER_USE_LINUX_SCREENSHOT_BACKEND` (`gnome-shell`,
`portal`, `gnome-screenshot`), `COMPUTER_USE_LINUX_FORCE_PORTAL_POINTER`
and `_KEYBOARD`, `COMPUTER_USE_LINUX_FORCE_YDOTOOL_POINTER` and
`_KEYBOARD`, `COMPUTER_USE_LINUX_FORCE_XDOTOOL_KEYBOARD`,
`CU_DISABLE_ABS_POINTER`, `COMPUTER_USE_LINUX_COSMIC_HELPER`. Set them in
the MCP server entry's `env` block, not globally.

## Security notes

`ydotoold` must run as a per-user service, never as root or system-wide.
Its socket grants arbitrary input synthesis to anything that can connect.
The MCP server itself is a privilege surface: anything Claude Code can
call, it can do on the desktop as James.
