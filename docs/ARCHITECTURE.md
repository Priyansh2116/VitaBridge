# Architecture

VitaBridge uses five Swift modules in both SwiftPM and the committed Xcode project. Xcode links the four internal library modules as static frameworks into the app, avoiding ad-hoc dynamic-library validation problems while retaining hardened runtime. SwiftPM provides fast XCTest execution; Xcode produces the signed native `.app`. Swift 6 strict concurrency is enabled, with deployment target macOS 14. No downloaded runtime dependencies.

## Input flow

```text
VitaPad-NG
  ├─ UDP 5000 discovery request/reply
  ├─ TCP 5000 V2 poll / heartbeat
  └─ UDP 5001 hello / stream
          ↓
VitaTransport serial descriptor owner
          ↓
VitaProtocol strict decoder + wrapping sequence tracker
          ├─ bounded latest snapshot → SwiftUI at 30 Hz
          └─ synchronous OutputPipeline (lock)
                  ↓
          ControllerEngine key/mouse union + transitions
                  ↓
          KeyboardMouseOutput → CoreGraphics
                  └─ independent release helper (stdin pipe)
```

The original Network.framework loopback simulator uses TCP 15000 / UDP 15001 to avoid AirPlay Receiver's wildcard port 5000 listener. It enters the identical transport and decoder. Simulator ports are explicit configuration, never sent to a real Vita by default. Network.framework NWPathMonitor is retained for path lifecycle; POSIX sockets implement existing broadcast discovery, exact TCP framing, UDP endpoint filtering and bounded cancellation. A dedicated dispatch worker owns all network descriptors. No unbounded input queue exists. Each incoming sample reaches mapping immediately; the UI reads only the latest snapshot.

## Modules

- **VitaProtocol:** normalized ControllerState, VitaButton, Stick, TouchPoint; strict 68/76-byte decoder; sequence loss/reordering accounting. Optional values are nil when absent. Little-endian reads are explicit and alignment-independent. Rejects malformed counts/coordinates, invalid battery and nonfinite motion. Unknown reserved fields/button bits are preserved/ignored for forward tolerance rather than guessed.
- **VitaTransport:** VitaConnectionManager handles discovery, manual private IPv4, response validation, UDP probe, hello, TCP keepalive, polling fallback and reconnect. One outstanding TCP request at a time; partial frames never cross session boundaries. Generation tokens cancel old sessions. Delivery and cancellation are serialized, and all waits check cancellation within 50 ms. Connected UDP sockets restrict input to the selected endpoint. A 64-datagram per-iteration bound protects heartbeat/cancellation work. No public listening socket in normal receiver mode.
- **ControllerEngine:** versioned Codable profiles and validation, radial dead zone, sensitivity, per-axis center/scale/inversion, stick assignment, button and touch bindings. Computes the union of all key demands before key-up transitions. Modifier key-down precedes ordinary keys; key-up order is reversed. Mouse velocity is integrated continuously even when packets stop changing.
- **OutputBackends:** independent monitor, USB no-op passthrough and keyboard/mouse implementations behind ControllerOutputBackend. VirtualHIDOutput reports a provisioning blocker and creates no device. OutputPipeline serializes mapping, configuration and event posting with a lock. Its 8 ms timer integrates mouse motion and resets after 300 ms without fresh input. Permission revocation neutralizes output. No injection starts automatically.
- **VitaBridgeApp:** SwiftUI dashboard, test diagram, mapping editor, settings, AppKit menu bar/lifecycle, ServiceManagement login item setting. AppModel owns the USB observer and refreshes controller inventory at 1 Hz, display at 30 Hz. GameController input is sampled for diagnostics, never forwarded into Wi-Fi injection.

## Independent crash release

When explicitly enabled, keyboard/mouse output launches the same packaged executable with `--release-watchdog`, before SwiftUI/AppKit initialization. The child reads a private pipe and records only the parent's mapped key and mouse holds. Parent writes hold records **before** key-down, removes holds **after** key-up, and sends heartbeats. The helper emits only release events on pipe EOF or 600 ms without a heartbeat. If the helper cannot launch, enable fails; if it exits, the pipeline pauses. The helper does not open network ports, receive arbitrary commands or send down events. `--watchdog-audit` logs the release decisions without posting CGEvents for process tests.

The child must inherit sufficient input-injection permission from the responsible signed app; this requires a real Accessibility-granted acceptance test. Neither process can guarantee release if both are forcibly killed, the OS crashes, or permission is revoked before a release can be posted. Physical press/release of the affected key is the recovery path. Crash protection is not a guarantee against operating-system failure.

## State and safety

Disconnect, explicit pause, profile/backend changes, sleep and clean shutdown release held inputs. Sleep suspends the connection and pauses output. Wake may reconnect if enabled, but injection requires another explicit Enable. Saved settings include manual IP, auto-reconnect, selected profile and output mode. Profiles save atomically to Application Support. Bad imports are rejected before replacing profiles; corrupt saved files remain intact until the user deliberately saves defaults. JSON files are bounded to 1 MiB and 100 profiles.

No synchronized clock exists in NG. Packet receive intervals and inferred sequence gaps are useful diagnostics; they are not one-way latency or proof of physical packet loss. A stream sender sequence reset forces a reconnect once no newer packets arrive; wrapping forward deltas work normally.

## USB

IOHIDManager matches gamepad/joystick usage collections and opens with no seize options. Device inventory reports product name, transport and VID/PID. Known VitaPad generic descriptor elements are normalized; GameController extended gamepad axes/buttons are separately visualized with selectable controller index. Sony DS4 identity is a candidate, not proof of Vita hardware. No device reports are rewritten and no synthetic gamepad is created.
