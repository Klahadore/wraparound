# WrapAround

A tiny macOS menu bar app that wraps your cursor horizontally: push it off the right edge
of the screen and it comes back on the left, and vice versa. Wrapping also works while
dragging, so you can drag a file in Finder (or a window, a selection…) across the
edge and drop it on the other side.

- **Left ↔ right only.** Top and bottom edges behave normally.
- **Quick kill switch:** press **⌃⌥⌘W** anywhere, or use the menu bar icon. The icon is
  filled when wrapping is on and a dim outline when it's off. The setting is remembered.
- **Launch at Login** toggle in the menu.
- Built for a single display. With several monitors it wraps at the outer edges of the
  whole desktop. If that gets in the way, switch it off with ⌃⌥⌘W.

## Install

### From a release
1. Download `WrapAround.zip` from [Releases](../../releases), unzip it, and move
   `WrapAround.app` to `/Applications`.
2. The app isn't notarized, so the first time you open it, right-click it and choose
   **Open**. Or run `xattr -dr com.apple.quarantine /Applications/WrapAround.app`.
3. Grant **Accessibility** access when asked: System Settings → Privacy & Security →
   Accessibility → WrapAround. Wrapping starts as soon as access is granted, without a
   restart.

### From source
Needs Xcode or the Command Line Tools (Swift 5.9+), macOS 13+.

```sh
./scripts/make-signing-cert.sh   # optional, once: a stable local signing identity so
                                 # the Accessibility grant survives rebuilds
./scripts/install.sh             # build, copy to /Applications, launch
```

## How it works

A Core Graphics event tap watches mouse-move and mouse-drag events. macOS pins the
cursor at the screen edge, but the event still carries the raw movement delta. When the
cursor sits on the right-most pixel and the delta still points right, or on the left-most
pixel and the delta points left, the app moves the cursor to the opposite edge at the same
height. It moves it by posting its own event from an event source whose "local events
suppression interval" is 0, not with `CGWarpMouseCursorPosition`, which makes macOS ignore
real mouse/trackpad input for 250 ms and kills the swipe's momentum. It also rewrites the
triggering event's location, so apps and in-progress drag sessions see
the new position immediately. The decision logic lives in `Sources/WrapCore` and is unit
tested.

## Tests

```sh
swift test            # unit tests for the wrap logic
./scripts/e2e.sh      # end-to-end against the installed app, using real posted HID events
```

`e2e/driver.swift` also has a `drag` command that performs a real Finder drag across the
edge: `build/driver drag <fromX> <fromY> <dropX> <dropY> [1|-1]`.

To debug, `defaults write com.klahadore.wraparound trace -bool true`, relaunch, and watch
`log stream --predicate 'subsystem == "com.klahadore.wraparound"'`.

## License

MIT
