# Compatibility

Statuses: **verified** means exercised here with recorded evidence; **expected** means supported by API/source but not exercised on the physical setup; **untested** means no consumer test; **maintainer-reported** is partial user hardware evidence without a complete reproducible acceptance record; **unavailable** means the backend is not implemented/authorized in this build. No upstream hardware claim is treated as a local result.

| Path / consumer | Status in VitaBridge | Scope / limits |
| --- | --- | --- |
| NG V2 Wi-Fi streaming | Verified with upstream fake Vita and original loopback simulator | Maintainer reports real Wi-Fi connectivity; structured hardware/router acceptance pending. Simulator tests use isolated ports, same packet bytes |
| NG V2 TCP polling fallback | Verified with upstream `--no-stream` | Real older V2 firmware pending |
| Discovery / manual IP | Verified with upstream simulator | Physical LAN broadcast/firewall/client isolation pending |
| Original VitaPad legacy | Unsupported, rejection verified with `--legacy` | Update to NG V2; ExtPadPacket not supported |
| VitaOxiPad | Unsupported | Different FlatBuffers protocol |
| Native USB DS4 | Maintainer reports USB input; full mapping/consumer checks pending | OS/games receive native `054C:09CC`; identity also matches a real DS4 |
| Generic USB gamepad | Expected HID inventory/known-descriptor visualization; hardware untested | `054C:5650`; GameController recognition not promised |
| Steam, native USB DS4 | Expected from upstream; game untested here | Verify in Steam Controller settings; no remapping or rumble is added by VitaBridge |
| Steam, Wi-Fi virtual gamepad | Unavailable | No authorized/provisioned virtual-HID backend |
| SDL games, native USB | Expected; game untested here | Generic mode may need per-game mapping; SDL version/hints vary |
| SDL games, Wi-Fi virtual HID | Unavailable | A descriptor alone does not establish SDL recognition |
| GameController games, native USB DS4 | Expected; game untested here | Select a GC-visible device in Controller Test |
| GameController games, generic USB | Untested; not guaranteed | HID enumeration and GC enumeration are separate facts |
| GameController games, Wi-Fi virtual HID | Unavailable | No system-wide GC controller is published |
| Emulators | Maintainer reports Astris receives USB input, with unresolved Start/R1 mapping | Not full game compatibility; Standard Gamepad profile is inert for Wi-Fi |
| Keyboard/mouse games | Mapping/transition logic verified; CGEvent consumer acceptance pending | Explicit Accessibility permission required; raw HID / anti-cheat / protected consumers can reject events |
| Front/rear Wi-Fi touch and motion | Decoder verified with fixtures and upstream simulator | Any-contact touch bindings supported; gesture/gyro aiming output not implemented |
| Rumble / lightbar | Unsupported in VitaBridge | Inspected NG USB firmware ignores output commands |
| macOS 14 and Intel runtime | Targeted; runtime untested on those systems | Build results and host OS recorded in TESTING.md |

## Virtual output boundary

The unavailable backend deliberately does not attempt restricted-entitlement execution or report success. CoreHID HIDVirtualDevice is macOS 15+; IOHIDUserDevice's public SDK also requires `com.apple.developer.hid.virtual.device`. Apple approval, matching provisioning and legitimate signing are needed before implementation can be runtime-tested. No SIP, AMFI or system security settings should be changed.

Future acceptance must show a separate application receiving actual state changes, separately for SDL and GameController, with consumer/version/OS recorded. An IOHID inventory listing or a successful compile is insufficient.

## Hardware and permission acceptance checklist

- Real Vita: discovery and manual IP, every physical button including PS, remapped L1/R1/L3/R3, stick center/extents/inversion, two contacts per panel, motion direction, battery, sleep/wake and Vita app exit/reopen.
- Wireless: real packet rate, weak Wi-Fi, reordered/drop behavior, competing client hello, Mac interface changes and reconnection. Measure end-to-end latency externally if needed; no one-way network metric is exposed.
- USB: both descriptor modes, name/transport/VID/PID, DS4 GameController visibility, independent game receives input with VitaBridge paused/closed, no duplicate events, unplug/replug, Vita LiveArea exit, remap menu neutralization, multiple controllers.
- Keyboard/mouse: grant Accessibility to a stable signed packaged app; test text editor/game input, shortcut flags, simultaneous/shared mappings, mouse movement/click/drag, disconnect while holding input, parent crash and stalled-parent helper release. Verify the helper inherits permission; tests of its audit log do not prove OS event acceptance.
- OS: macOS 14 and later supported releases, Intel hardware, signed/notarized launch, login item approval, sleep/wake, Accessibility revocation. Maintainer reports are partial evidence, not completion of these structured hardware/game acceptance checks.
