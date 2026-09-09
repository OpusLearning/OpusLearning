#!/usr/bin/env bash
# Installs computer-use-linux on this Linux desktop, prepares the system
# pieces it needs, registers it as a user-scope MCP server in Claude Code
# and prints the doctor readiness block.
#
# Usage:
#   install.sh                 full install with the best available method
#   install.sh --check         run doctor only
#   install.sh --no-mcp        skip Claude Code MCP registration
#   install.sh --method npm|binary|cargo
#
# Safe to re-run. Nothing here needs sudo; the script prints the apt
# commands for missing system packages instead of running them.

set -euo pipefail

method=""
do_mcp=1
check_only=0
while [ $# -gt 0 ]; do
  case "$1" in
    --check) check_only=1 ;;
    --no-mcp) do_mcp=0 ;;
    --method) method="${2:-}"; shift ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

if [ "$(uname -s)" != "Linux" ]; then
  echo "computer-use-linux only runs on Linux desktops." >&2
  exit 1
fi

bin_dir="$HOME/.local/bin"
mkdir -p "$bin_dir"
case ":$PATH:" in *":$bin_dir:"*) ;; *) export PATH="$bin_dir:$PATH" ;; esac

find_binary() {
  command -v computer-use-linux 2>/dev/null || true
}

readiness() {
  local bin; bin="$(find_binary)"
  if [ -z "$bin" ]; then
    echo "computer-use-linux is not installed." >&2
    return 1
  fi
  if command -v jq >/dev/null 2>&1; then
    "$bin" doctor | jq .readiness
  else
    "$bin" doctor
  fi
}

if [ "$check_only" = 1 ]; then
  readiness
  exit $?
fi

install_npm() {
  command -v npm >/dev/null 2>&1 || return 1
  echo "Installing @agent-sh/computer-use-linux with npm..."
  npm install -g @agent-sh/computer-use-linux
}

install_binary() {
  command -v curl >/dev/null 2>&1 || return 1
  command -v sha256sum >/dev/null 2>&1 || return 1
  local arch target base tmp
  arch="$(uname -m)"
  case "$arch" in
    x86_64) target=x86_64-unknown-linux-gnu ;;
    aarch64|arm64) target=aarch64-unknown-linux-gnu ;;
    *) echo "No prebuilt binary for $arch" >&2; return 1 ;;
  esac
  base="https://github.com/agent-sh/computer-use-linux/releases/latest/download"
  tmp="$(mktemp -d)"
  echo "Downloading prebuilt binaries for $target..."
  local b asset
  for b in computer-use-linux computer-use-linux-cosmic; do
    asset="$b-$target"
    curl -fsSL -o "$tmp/$asset" "$base/$asset"
    curl -fsSL -o "$tmp/$asset.sha256" "$base/$asset.sha256"
    (cd "$tmp" && sha256sum -c "$asset.sha256")
    install -m 0755 "$tmp/$asset" "$bin_dir/$b"
  done
  rm -rf "$tmp"
}

install_cargo() {
  command -v cargo >/dev/null 2>&1 || return 1
  echo "Installing with cargo (this builds from source)..."
  cargo install computer-use-linux
}

if [ -z "$(find_binary)" ]; then
  case "$method" in
    npm) install_npm ;;
    binary) install_binary ;;
    cargo) install_cargo ;;
    "") install_npm || install_binary || install_cargo || {
          echo "Could not install: need npm, or curl+sha256sum, or cargo." >&2
          exit 1
        } ;;
    *) echo "unknown --method $method" >&2; exit 2 ;;
  esac
else
  echo "Found $(find_binary)"
fi

bin="$(find_binary)"
[ -n "$bin" ] || { echo "Install finished but binary not on PATH. Add $bin_dir to PATH." >&2; exit 1; }

# System packages: report, do not sudo.
missing=()
session="${XDG_SESSION_TYPE:-}"
desktop="${XDG_CURRENT_DESKTOP:-}"
if [ "$session" = "x11" ] && ! command -v xdotool >/dev/null 2>&1; then
  missing+=(xdotool)
fi
if [ "$session" = "wayland" ] && ! command -v ydotool >/dev/null 2>&1; then
  missing+=(ydotool)
fi
if ! command -v at-spi-bus-launcher >/dev/null 2>&1 \
   && ! ls /usr/libexec/at-spi-bus-launcher /usr/lib/at-spi2-core/at-spi-bus-launcher \
         /usr/lib/*/at-spi2-core/at-spi-bus-launcher >/dev/null 2>&1; then
  missing+=(at-spi2-core)
fi
if [ "${#missing[@]}" -gt 0 ]; then
  echo
  echo "Optional system packages not found: ${missing[*]}"
  echo "On Debian or Ubuntu:  sudo apt install ${missing[*]}"
  echo "Doctor below will say whether they are actually required."
  echo
fi

# AT-SPI bridge (gsettings; harmless elsewhere).
if command -v gsettings >/dev/null 2>&1; then
  if command -v jq >/dev/null 2>&1; then
    "$bin" setup | jq -r '.message // empty' || echo "setup failed; see doctor output." >&2
  else
    "$bin" setup >/dev/null || echo "setup failed; see doctor output." >&2
  fi
fi

# GNOME Wayland exact window targeting.
if [ "$session" = "wayland" ] && printf '%s' "$desktop" | grep -qi gnome; then
  "$bin" setup-window-targeting || echo "setup-window-targeting failed; see doctor output." >&2
  echo "If the GNOME Shell extension was newly installed, log out and back in."
fi

# ydotoold per-user service when the unit exists.
if command -v systemctl >/dev/null 2>&1 \
   && systemctl --user list-unit-files ydotoold.service 2>/dev/null | grep -q '^ydotoold'; then
  systemctl --user enable --now ydotoold 2>/dev/null || true
fi

# Register with Claude Code at user scope.
if [ "$do_mcp" = 1 ]; then
  if command -v claude >/dev/null 2>&1; then
    if claude mcp get computer-use-linux >/dev/null 2>&1; then
      echo "Claude Code MCP server 'computer-use-linux' already registered."
    else
      claude mcp add --scope user computer-use-linux -- "$bin" mcp
      echo "Registered 'computer-use-linux' MCP server at user scope."
    fi
  else
    echo "claude CLI not found; register manually:"
    echo "  claude mcp add --scope user computer-use-linux -- $bin mcp"
  fi
fi

echo
echo "Readiness:"
readiness || true
echo
echo "Restart Claude Code (or run /mcp) so the tools load."
