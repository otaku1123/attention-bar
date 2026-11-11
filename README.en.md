# AttentionBar

[日本語](README.md)

A macOS menu bar app that shows what needs your attention right now. It picks the most important item from your Calendar and Reminders, shows it in the menu bar, and lists the next few in a popup.

- Requires macOS 13 or later
- No third-party libraries (SwiftUI / EventKit / ServiceManagement)
- No network access. Calendar and Reminders are read locally on your Mac ([Privacy Policy](PRIVACY.md))
- English and Japanese, following your macOS language setting

## Features

- Always shows the time until your next event or reminder in the menu bar (e.g. `📅 Next in 12m`)
  - During a meeting of up to 2 hours, shows the time left until it ends (e.g. `📅 Weekly sync… 27m left`). If another meeting starts right after, the popup tells you
- Click to see the top items in priority order
  - Join a meeting with one click when the event has a meeting URL (Zoom, Google Meet, Microsoft Teams, Webex, Slack huddles, and more)
  - Mark reminders as done, snooze them (in 1 hour, this evening, or tomorrow morning), or hide events you don't need to see
- Notifies you 5 minutes before an event starts (configurable), and alerts you on top of other windows at the start time with a panel or a full-screen overlay (optionally 30 seconds to 2 minutes early)
- Choose what the menu bar shows (title and time, time only, or icon only), which calendars to show, how far ahead to look, when to notify, and whether to launch at login

## Installation

1. Download the latest `AttentionBar-<version>.zip` from [Releases](https://github.com/otaku1123/attention-bar/releases) and double-click it to unzip
2. Move `AttentionBar.app` to `/Applications` and open it
3. Allow access to Calendars and Reminders
4. To start it automatically, open Settings from the popup and turn on "Launch at Login" (after moving the app to `/Applications`)

The app is signed with a Developer ID and notarized by Apple, so it opens without Gatekeeper warnings.

Please report bugs and requests in [Issues](https://github.com/otaku1123/attention-bar/issues).

## Troubleshooting

| Symptom | What to do |
|---|---|
| Permission changes in System Settings don't take effect | Restart the app |
| The menu bar item disappears, e.g. during a meeting | The menu bar is out of space and macOS hides items from the left. Hold ⌘ and drag the item to the right (near the clock), or quit menu bar apps you don't need |
| "Apple could not verify…" on another Mac | Make sure the app came from the Releases zip. Check with `spctl --assess --type execute --verbose /Applications/AttentionBar.app` (it should say `Notarized Developer ID`) |

## Development

```bash
open AttentionBar.xcodeproj
```

Run from Xcode, or build and test from the command line:

```bash
xcodebuild build -project AttentionBar.xcodeproj -scheme AttentionBar -derivedDataPath build
xcodebuild test  -project AttentionBar.xcodeproj -scheme AttentionBar -destination 'platform=macOS' -derivedDataPath build
open build/Build/Products/Debug/AttentionBar.app
```

To check the English UI on a Japanese Mac, launch it with `open build/Build/Products/Debug/AttentionBar.app --args -AppleLanguages '(en)'`.

Strings are in `AttentionBar/Localizable.xcstrings` (Japanese is the source language). Release, notarization, and TestFlight procedures are documented in the [Japanese README](README.md).

## License

[MIT License](LICENSE)
