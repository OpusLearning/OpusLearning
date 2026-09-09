# Recipes

Each recipe assumes the setup check in SKILL.md has passed. Tool names
are shortened; in Claude Code prefix them with `mcp__computer-use-linux__`.

## 1. Find a saved password for a host (for example 192.168.6.1)

Goal: tell James whether a browser has a saved login for the host and,
if so, what it is. He types any master or system password himself.

1. `list_windows` to see which browsers are open. If none, ask James
   which browser he uses, then open it with `press_key` `Super` and
   `type_text`, or via the Bash tool (`xdg-open`, `firefox`,
   `google-chrome`), then `activate_window` by `wm_class`.
2. Open the password manager page in a new tab:
   - Chrome or Chromium: `press_key` `Ctrl+T`, then `Ctrl+L`, then
     `type_text` `chrome://password-manager/passwords`, then `Enter`.
   - Edge: `edge://wallet/passwords`.
   - Brave: `brave://password-manager/passwords`.
   - Firefox: `about:logins`.
3. `get_app_state` with `include_screenshot: false`. Find the search
   field (role `entry` or `text`) and use `set_value` or a `click` then
   `type_text` with the host, for example `192.168.6.1`.
4. Re-observe. If an entry appears, `click` it, then click the reveal
   control (Chrome names it "Show password", Firefox "Show" or the eye
   icon).
5. The OS or browser may prompt for the login or keyring password. Stop
   and ask James to type it. Do not type it yourself.
6. Once revealed, `get_app_state` or `screenshot` and read the username
   and password. Report both to James in the reply. Do not persist them.
7. If nothing matches, also search for `192.168.6.1` without the scheme,
   the router's hostname if known, and the vendor name. If still empty,
   say so and suggest the label on the router or the ISP's default.

Terminal fallback if the browser is closed and James prefers it:

- GNOME keyring holds Chrome's encryption key and any web logins saved
  by GNOME Web: `secret-tool search --all xdg:schema chrome_libsecret_os_crypt_password_v2`
  reveals only the key, not the passwords. Chrome's actual entries live
  in `~/.config/google-chrome/Default/Login Data` (SQLite, encrypted).
  Reading them needs a decryption tool; prefer the GUI route above.
- Firefox stores logins in `~/.mozilla/firefox/<profile>/logins.json`
  encrypted with `key4.db`. The GUI route is simpler and safer.

## 2. Work through a router admin page

1. Open the browser and navigate to `http://192.168.6.1` (`Ctrl+L`,
   `type_text`, `Enter`).
2. `get_app_state` with a screenshot. Browsers may autofill a saved
   login; if the username field is already populated the browser has a
   saved credential, which answers the "is there a saved password"
   question even before revealing it.
3. Do not click Log in until James confirms. Router admin actions can
   reboot the network, which would also cut Claude Code's connection.
4. Once logged in, use `get_app_state` to read settings pages. Prefer
   the accessibility tree; router UIs are usually plain HTML forms and
   expose their fields.
5. Ask before saving or applying any change.

## 3. Read text from an app without changing it

1. `list_windows`, note the `window_id`.
2. `get_app_state` with `window_id` and `include_screenshot: false`.
3. Walk the tree for `text`, `label`, `heading` and `document` roles.
4. If the tree is empty (Electron before restart, canvas apps), take a
   `screenshot` with the window target and read the image instead.

## 4. Fill a form

1. `get_app_state` for the window.
2. For each field, `set_value` by `element_index` where the element is
   editable. Fall back to `click` then `type_text` when `set_value` fails.
3. For checkboxes and radios use `perform_action` (`Toggle`).
4. Re-observe before pressing any submit control, and confirm with
   James if the form sends, pays or commits anything.

## 5. Terminal targeting

`list_windows` enriches terminal windows with `tty`, foreground command
and cwd. Use `type_text` or `press_key` with `terminal_command` or
`terminal_cwd` to hit the right shell without a window id, for example
sending `q` to the terminal running `less`.

## 6. Recover an off-screen window

`list_windows` reports bounds; results warn if a target is partly
off-screen. Use `move_window` with `target: {window_id: N}, x: 0, y: 0`
then `resize_window` to fit, then continue.
