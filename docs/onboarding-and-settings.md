# Onboarding, permissions and Settings

Read this before changing `src/onboarding.rs`, `src/settings.rs`, `src/command_line.rs` or the helper's `Onboarding.swift`, `PermissionPanel.swift` and `Settings.swift`.

## Onboarding (`src/onboarding.rs`, `helper/Onboarding.swift`)

Rust decides what shows (`Flow`, `launch_plan`, `Gate`, tested) and stores progress under `"onboarding"` in `~/.config/scrawl/config.json`, including the tour's current step (`resume`), so any quit (macOS's "Quit & Reopen" too) picks up there; the SwiftUI window in `scrawl-helper onboarding` only renders the state it's sent and reports buttons (`grant:<permission>` for a row).

Tour: Welcome → HowItWorks → Permissions (one checklist of three required rows, Screen Recording first, then Microphone and Accessibility; any order works) → TryIt → Done. Camera (iPhone) is never in the tour: its first use opens `Flow::fix(vec![Camera])`, the same screen with one row.

Input Monitoring is never asked for or read (macOS wants a relaunch after it; the enum variant stays only so 0.3.x configs load, and `input_monitoring_is_never_requested` greps the sources): clicks come from an `NSEvent` global mouse monitor (no permission), ⇧ and held modifiers from `CGEventSourceFlagsState` (no permission), keys from an active `kCGEventTapOptionDefault` tap (Accessibility), which the HID poller makes or stops every 500 ms as `AXIsProcessTrusted` changes (`check_key_tap`; live, no relaunch). Never poll key codes (`CGEventSourceKeyState`) or make a listen-only tap.

Grants are re-read every 0.5 s from a fresh `scrawl-helper permissions`; the coordinator caches them (`ScrawlCoordinator::grants`).

macOS shows "Quit & Reopen / Later" the moment Screen Recording is granted, and a running process may not see the grant (`CGPreflightScreenCaptureAccess` caches). So once the helper says granted, `read_grants` tries a one-frame ScreenCaptureKit capture in this process (`capture::screen_capture_usable(true)`); if it fails, `Flow::tick` shows "Reopening Scrawl" for `RELAUNCH_AFTER_MS` and returns `Effect::Relaunch`, and the coordinator saves `Progress::relaunching` (tour `resume` = Permissions, or `reopenFix`) and `onboarding::relaunch()` reopens the app (without `-n`) after this pid exits. Quit & Reopen lands in the same place through the saved `resume`; a tour resumed on Permissions stays there. `relaunchedAt` stops a second automatic relaunch within `RELAUNCH_GUARD_MS`; the row then offers Reopen Scrawl. `scrawl sck-probe [--watch S]` / `scrawl-helper sck-probe` test whether a grant reaches a running process.

Until the required ones are on, ⌥⇧S and the menu's record items start nothing (no switcher, picker or overlay; the picker sits at `NSStatusWindowLevel + 1` and takes clicks, which trapped macOS prompts under it): `Gate` holds the request and `tick_gate` opens or raises the window once the modifiers are up. Capture code must not call `CGRequestScreenCaptureAccess` or start the iPhone mirror without Camera: go through `ready_to_record` / `ready_for`.

Render every screen and permission state with `scrawl-helper onboarding --render DIR`.

Rows for draggable lists (`Permission::draggable`: Screen Recording, Accessibility) go straight to `OpenSettings`, which launches `scrawl-helper permission-panel` (`helper/PermissionPanel.swift`) from the row's button: the card flies to just below System Settings (inside its empty lower area when the screen has no room; `PermissionPanel.dock`, checked by `scripts/check-permission-panel-dock.sh`), drags the `Scrawl.app` that contains the helper, reads grants from a fresh `--check` process (never trusts the drop), and is told `granted` when the row turns on. Preview it with `permission-panel --permission screen-recording --preview`; never `tccutil reset` Kit's real grants to test it.

## Settings (`src/settings.rs`, `helper/Settings.swift`)

The onboarding pattern again. `scrawl-helper settings` draws the `View` it's sent (General, Recording, Storage, Permissions, Agents, About; ⌘, or the menu's **Settings…**, and **Open Settings** on onboarding's last screen) and reports actions as JSON lines; `Panel` decides and writes `~/.config/scrawl/config.json` through `handoff::set_config_value_in` (other keys and `0600` kept).

Both shortcuts (`ShortcutKind::Record` ⌥⇧S, `Paste` ⌥⇧V) live under `"shortcuts"` (Carbon `keyCode`/`modifiers`/`label`; absent is the default; 0.3.x's file under Application Support is moved across once). Clicking a keycap row sends `record-shortcut`: Rust pauses every Scrawl hotkey (`capture::pause_shortcuts`: Carbon unregistered, `emit_*` muted) so the current combo reaches the recorder, then `settings::validate` turns down combos without ⌘/⌥/⌃ (function keys excepted), ⌘ + one key, macOS's own (a static list plus the helper's enabled `CopySymbolicHotKeys`) and the other shortcut; `capture::set_shortcuts` registers both and puts the old ones back if `RegisterEventHotKey` refuses. Only a default answers to its aliases (⌃/⌘ added, ⌃⌥⌘, the ANSI key); a custom combo matches exactly in Carbon and the key event tap.

Launch at login is `SMAppService.mainApp` (only inside Scrawl.app). There's no Dock icon: gpui 0.2.2 makes the app Regular after launch despite `LSUIElement`, so `ui::stay_out_of_dock` sets Accessory again at the top of `run_app`. The menu keeps Record, Choose What to Record…, Open Latest Capture, Export (flag), Settings…, Check for Updates…, Quit.

Agents › Command-line tool (`src/command_line.rs`) symlinks the app's own binary (its real path, which is how it finds `scrawl-helper`) into the first writable of `/opt/homebrew/bin`, `/usr/local/bin`, else `~/.local/bin`; it never asks for admin, never touches a `scrawl` that doesn't link to a Scrawl.app, and the Homebrew cask's `binary` link reads as installed. A bare `scrawl` from a terminal prints help instead of starting a second app. Agents › Agent skill shows `bunx skills add kitlangton/scrawl` (`skills/scrawl/SKILL.md`, also printed by `scrawl skill`); keep that file true to the CLI.

Render every pane (dark, light, recorder listening, refused) with `scrawl-helper settings --render DIR`; test with `cargo test settings::`.

## Stable local signing

`install-app.sh` resolves a signing certificate before modifying the installed app.
Set it once per checkout (not committed, shared by branches):

```sh
security find-identity -v -p codesigning
git config --local scrawl.signingIdentity <certificate-SHA-1>
```

`SCRAWL_SIGN_IDENTITY` overrides that setting for one invocation. Without either,
the original developer's identity is used. Names must match exactly and uniquely;
use the SHA-1 when multiple certificates have the same name. Missing or ambiguous
identities abort instead of silently falling back to ad-hoc signing. Explicit
`SCRAWL_SIGN_IDENTITY=-` remains available for disposable builds, with a warning.

Use the same certificate, bundle IDs, and installed path across rebuilds. Switching
from an ad-hoc build to certificate signing can require granting permissions once
more; subsequent builds have a stable designated requirement. No privacy grants
are reset or edited by the installer.

### Fork-only installer across feature branches

Keep signing changes on `fix/persistent-local-signing` in the fork; do not merge
that branch into upstream feature PRs. Configure a checkout-local Git alias once:

```sh
git config --local alias.scrawl-install '!f() { local_runner=$(git show refs/heads/fix/persistent-local-signing:scripts/install-fork-local.sh) && bash -c "$local_runner"; }; f'
git scrawl-install
```

This extracts only the installer scripts into a temporary directory and builds
whatever source (including uncommitted changes) is currently checked out. It
never switches branches or adds signing files to the feature diff. The temporary
installer runs `scripts/install-app.sh` with `SCRAWL_REPO_DIR` pointing at that
checkout; certificate selection still comes from its local Git config. The alias
and certificate selection survive branch switches and rebases. Do not use the
upstream installer directly on feature branches: it can still fall back to ad-hoc
signing. After cloning elsewhere, fetch the signing branch and configure the
alias and certificate there too.
