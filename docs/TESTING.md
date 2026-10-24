# Testing

## Reproducible automated commands

```sh
./scripts/test.sh
./scripts/test-upstream.sh
xcodebuild -project VitaBridge.xcodeproj -scheme VitaBridge \
  -destination 'platform=macOS' -derivedDataPath build test
./scripts/build.sh
python3 scripts/check-watchdog.py build/Build/Products/Release/VitaBridge.app/Contents/MacOS/VitaBridge
```

`test.sh` runs the original loopback server plus protocol, mapping, profile, backend and watchdog-ledger tests. Seven upstream-specific cases explicitly skip without `VITABRIDGE_FAKE_VITA`. They are not counted as verified integration success when skipped. `test-upstream.sh` fetches/validates the source revision recorded in RESEARCH and sets that environment variable. Python 3 is needed only for the upstream test process, not for the app/demo.

To reuse an existing exact upstream checkout:

```sh
VITABRIDGE_FAKE_VITA=/path/to/VitaPad-NG/tools/fake_vita.py ./scripts/test.sh
```

Tests spawn one upstream simulator at a time and terminate it after each case. The harness compiles its original source into a Python namespace, sets only `PORT=15000` and `STREAM_PORT=15001`, then invokes its original main. This is necessary because this Mac's AirPlay Receiver owns TCP 5000. Packet code, flags, connection behavior and discovery payloads are unchanged. This proves protocol interoperability on loopback; physical port/firewall behavior is a hardware check. Production defaults are always Vita ports 5000/5001. Do not run another simulator or the app demo during tests.

## Scenarios

| Area | Automated coverage |
| --- | --- |
| NG wire format | Exact request/hello bytes, 68/76-byte lengths, button masks, signed normalized axes, touch contacts, accel/gyro, battery, timestamp/sequence |
| Decoder rejection | Truncation, extra bytes, wrong magic, legacy response, invalid touch count/coordinate/battery, nonfinite motion |
| Stream ordering | Missing sequences, duplicates, backward sequences, uint32 wrap |
| Connection | Original demo via real TCP/UDP, upstream discovery/manual/no-discovery, legacy rejection, no-stream fallback, injected stream loss, forced drop/reconnect, sudden server exit |
| Mapping | Press/release, simultaneous/shared keys, modifier order, mouse click/velocity, touch binding, dead zone/inversion, 1000 rapid press/release cycles, neutral reset |
| Persistence | Atomic roundtrip, invalid version/dead zone/key code, malformed JSON |
| Backends | Monitor and native USB no-op behavior, distinct selection, virtual blocker |
| Crash helper | Ledger rejects invalid commands; process audit checks pipe EOF and a still-open stalled parent, without injection |

Receive callbacks are observed through a locked recorder using the production mapping engine. Disconnect tests assert no held mapped keys and no stale generation callbacks. Test failures stop completion; they are not masked by simulator UI animation.

## Evidence from this checkout

The final build/test results are recorded in [VERIFICATION.md](VERIFICATION.md). That record distinguishes Xcode/SwiftPM builds, simulator interoperability, helper audit, application launch and consumer/hardware verification. No physical Vita, USB device, game or Accessibility authorization is assumed.

## Manual acceptance

1. Start Loopback Demo and check every screen, packet rate and clearly marked simulated state.
2. Create a custom profile with a shared key and shortcut; save, quit/relaunch, export/import and verify persistence. Invalid import must preserve the current configuration.
3. With explicit Accessibility permission, send input to a disposable text editor and a mouse target. Verify shortcuts, movement, mouse drag and focus behavior. Never use a password field as the test target.
4. Pause, disconnect, change profile/backend, sleep and quit while holding inputs. The target must see releases; wake requires explicit re-enable.
5. Force the parent app to exit while holding a mapped input and verify independent helper release in the target. Separately suspend the parent and verify the helper timeout. Audit-only tests do not substitute for this permission-dependent test.
6. Repeat with physical Vita over Wi-Fi, then both USB modes. Verify native input reaches a separate game even when VitaBridge is paused/closed.
7. Test multiple real controllers, per-device selection, actual DS4 identity versus Vita, weak Wi-Fi and interface changes.
8. On legitimately authorized virtual-HID work later, test IOHID publication, GameController recognition and SDL state in separate consumer apps before marking any virtual backend working.
