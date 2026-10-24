# Set up the Mac

Requirements: macOS 14+, full Xcode with Swift 6 for building, homebrew-capable Vita running VitaPad-NG for hardware use. Source targets Apple Silicon and Intel; this checkout's actual verification is recorded in TESTING.md.

## Build

```sh
./scripts/build.sh
open build/Build/Products/Release/VitaBridge.app
```

The committed Xcode project is self-contained. To regenerate it after source/target configuration changes, install XcodeGen separately and run `xcodegen generate`. SwiftPM has no external package dependencies. For a universal release:

```sh
xcodebuild -project VitaBridge.xcodeproj -scheme VitaBridge \
  -configuration Release -derivedDataPath build \
  ONLY_ACTIVE_ARCH=NO ARCHS='arm64 x86_64' build
```

Local builds use ad-hoc signing. Use your own Developer ID signing/notarization for distribution and a stable signing identity for reliable permission retention. The main app is not App Sandbox-enabled because global CGEvent injection is its explicit user-enabled function. Normal usage does not require administrator access, system extensions or virtual-HID entitlements.

## Connect and monitor

Allow Local Network access if macOS prompts. Discover broadcasts only on local interfaces; manual connection accepts private, loopback and link-local IPv4 addresses. IPv6 and public IPv4 addresses are not supported. On the same trusted LAN, choose Discover or enter the Vita IP. Use Controller Test to check input. No Accessibility access is needed for Wi-Fi monitoring.

Use Start Loopback Demo without hardware. It binds only to loopback ports **15000/15001**, intentionally avoiding macOS AirPlay Receiver's common TCP 5000 listener. The production Vita connection always defaults to 5000/5001. The demo does not need Python.

## Keyboard/mouse output

1. Select Keyboard / Mouse, then Keyboard Gaming, FPS Keyboard/Mouse, or a custom profile. Standard Gamepad is an inert mapping template; selecting it does not create a virtual gamepad.
2. Read the explanation in Settings. Click **Grant Accessibility** only when ready to allow injection.
3. In System Settings → Privacy & Security → Accessibility, enable VitaBridge. Reopen the app if macOS requires it after changing permission.
4. Connect Wi-Fi or the demo, then explicitly click **Enable Keyboard / Mouse**. Focus your game or a test editor. VitaBridge sends to the focused app; it does not target a process secretly.
5. Use the menu-bar Pause control before editing mappings or switching to another application. Mode/profile changes, disconnection and sleep release holds and pause as documented. Wake reconnects when configured but does not re-enable injection.

Default keyboard profile: left stick WASD, right stick mouse, Cross Space, Circle Escape, Square E, Triangle R, L left Shift, R left Control, Start Return, Select Tab, D-pad arrows. FPS profile changes L/R to right/left mouse. Mapping Editor supports any virtual key code 0–127, key combinations, mouse clicks, stick assignment, radial dead zone, sensitivity, axis inversion, center/range calibration, front/rear touch contact mappings. Codes are macOS hardware virtual keys, so text produced follows your active keyboard layout.

Release protection includes a 300 ms input freshness timeout and independent helper for parent exit/stall. Permission and target-game restrictions can prevent injection; games using raw HID or anti-cheat may ignore synthetic events. See compatibility and acceptance tests.

## Profiles and menu bar

Save after editing. Duplicate creates another game profile. Import validates and replaces the profile set; export writes the full profile list to versioned JSON. Active profile and connection settings persist. Closing the main window leaves the menu-bar utility running. Quit from its menu for clean release. Launch at login uses SMAppService and may require enabling the item in macOS Login Items settings; it is meaningful for the packaged app, not `swift run`.

## Native USB

Switch firmware to USB mode and connect a data cable. Open native controller diagnostics. Input remains directly available to games; VitaBridge never seizes the device. macOS may restrict raw IOHID input observation through Input Monitoring; no Input Monitoring prompt is requested by VitaBridge. GameController observations can still be available. Inventory may show other controllers, and a real DS4 shares the same identity as the Vita's DS4 mode.
