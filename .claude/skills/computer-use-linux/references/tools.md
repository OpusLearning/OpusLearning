# MCP tool reference

Tool names in Claude Code take the form `mcp__computer-use-linux__<tool>`.
Parameter names below come from the upstream server (v0.5.0, `src/server.rs`).
All parameters are optional unless marked required.

## Window target fields

Several tools accept the same optional target fields to pick a window:
`window_id` (u64), `pid`, `app_id`, `wm_class`, `title`, plus terminal
selectors `tty`, `terminal_pid`, `terminal_command`, `terminal_cwd`.
`click`, `scroll` and `screenshot` use `window_title` or `title` as noted.
When a target is given the window is raised and focused first.

## Element selector fields

Tools that act on accessibility elements accept `element_index` (from the
latest `get_app_state`), or a semantic selector of `role`, `name`, `text`
and `states` (array of state names such as `focused`, `checked`,
`editable`). `perform_action` and `set_value` also take
`element_identifier`.

## Diagnostics

| Tool | Parameters | Notes |
| --- | --- | --- |
| `doctor` | none | Full JSON readiness report. Read `.readiness` first. Read-only. |
| `setup_accessibility` | none | Runs gsettings to enable the GNOME AT-SPI bridge. Idempotent. |
| `setup_window_targeting` | none | Installs and enables the bundled GNOME Shell extension. Needs a log out and in afterwards. |

## Discovery (read-only)

| Tool | Parameters | Notes |
| --- | --- | --- |
| `list_apps` | none | Apps visible to the AT-SPI registry. |
| `list_windows` | none | Title, app id, wm_class, focus, client type, bounds, terminal info. |
| `focused_window` | none | The window holding keyboard focus. |
| `get_app_state` | `app_name_or_bundle_identifier`, window target fields, `max_nodes` (default 1000, max 2000), `max_depth` (default 32, max 64), `include_screenshot`, `max_width`, `max_height`, `max_bytes`, `scale`, `format` (`png` or `jpeg`), `quality` (1 to 95), `verbose` | Returns a compact readiness block, the accessibility tree with element indices, and a screenshot unless `include_screenshot: false`. May trigger the screenshot portal prompt. |
| `screenshot` | `window_id`, `pid`, `app_id`, `wm_class`, `title`, `raise_window`, `full_screen`, `max_width`, `max_height`, `max_bytes`, `scale`, `format`, `quality` | Default cap 1920 px and 2 MiB. With a window target the window is raised and the image cropped. Metadata includes `coordinate_width`, `coordinate_height` and `scale` for converting preview pixels to desktop coordinates. |

## Input (mutating)

| Tool | Parameters | Notes |
| --- | --- | --- |
| `click` | element selector fields, or `x`, `y`; `button` (`left`, `middle`, `right`), `click_count`; window target via `window_id`, `pid`, `app_id`, `wm_class`, `window_title`; `relative` | `relative: true` makes `x`/`y` relative to the targeted window, matching a window-cropped screenshot. |
| `drag` | `start_x`, `start_y`, `end_x`, `end_y` (all required) | Desktop coordinates. |
| `scroll` | `direction` (required: `up`, `down`, `left`, `right`), `pages`, `element_index` or `x`, `y`; window target via `window_id`, `pid`, `app_id`, `wm_class`, `window_title`; `relative` | With a window target and no position, scrolls at the window centre. |
| `press_key` | `key` (required), window target fields | Combos join with `+`, e.g. `Ctrl+L`, `Ctrl+Shift+T`. Modifiers: ctrl, alt, shift, meta/super. Named keys: enter, escape, tab, backspace, delete, space, home, end, pageup, pagedown, left, right, up, down, f1 to f12, plus a to z and 0 to 9. Anything else errors. Compositor shortcuts such as Super+Up may be eaten by GNOME. |
| `type_text` | `text` (required), window target fields | Literal text. Prefers portal or wtype on Wayland, xdotool on X11, ydotool as fallback. Result reports the focused element and warns if nothing editable has focus. |

## Semantic actions (mutating)

| Tool | Parameters | Notes |
| --- | --- | --- |
| `perform_action` | element selector fields, `element_identifier`, `action` | Invokes an AT-SPI action such as `Press`, `Activate`, `Toggle`. Defaults to the element's primary action. |
| `set_value` | element selector fields, `element_identifier`, `value` (required) | Writes to text fields, sliders and spinners without synthesising keystrokes. |

## Navigation

| Tool | Parameters | Notes |
| --- | --- | --- |
| `activate_window` | window target fields | Focus a window. |
| `move_window` | `target` (object of window target fields), `x`, `y` | GNOME extension or wmctrl only. Recovers off-screen windows. |
| `resize_window` | `target`, `width`, `height` | Unmaximises first if needed. |

## Conditional

`run_shell` exists only when the server was started with
`COMPUTER_USE_LINUX_ENABLE_SHELL=1`. It is not sandboxed. Do not enable it;
use Claude Code's Bash tool instead.

## Safety annotations

The server publishes MCP tool annotations. `doctor`, `list_apps`,
`list_windows`, `focused_window` and `get_app_state` are read-only.
`setup_*` change desktop configuration. `activate_window`, `move_window`,
`resize_window`, `scroll` and `screenshot` change focus or geometry.
`click`, `drag`, `press_key`, `type_text`, `perform_action` and
`set_value` are destructive and open-world: they can trigger anything
the targeted app can do.
