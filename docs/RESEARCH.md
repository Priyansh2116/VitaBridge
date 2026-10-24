# Research findings

Inspected source on 2026-10-24, before implementing the wire decoder. Exact revisions are in [UPSTREAM_REVISIONS.md](UPSTREAM_REVISIONS.md). VitaBridge is an independent implementation; no upstream source, firmware, descriptors or artwork is bundled.

## VitaPad-NG

Sources: [Common/protocol.h](https://github.com/bclarke123/VitaPad-NG/blob/bfecfd258dee02b495a1c0f91abb34939647475a/Common/protocol.h), [Client/main.cpp](https://github.com/bclarke123/VitaPad-NG/blob/bfecfd258dee02b495a1c0f91abb34939647475a/Client/main.cpp), [Server/source/main.c](https://github.com/bclarke123/VitaPad-NG/blob/bfecfd258dee02b495a1c0f91abb34939647475a/Server/source/main.c), [TESTING.md](https://github.com/bclarke123/VitaPad-NG/blob/bfecfd258dee02b495a1c0f91abb34939647475a/TESTING.md), and tools/fake_vita.py were read.

- Discovery: UDP broadcast to port 5000; ASCII `VITAPAD_DISCOVER`, without NUL; reply `VITAPAD_HERE`, without NUL. VitaBridge checks the exact reply and source port and accepts private, link-local and loopback IPv4 addresses only.
- TCP: client connects to the Vita on port 5000 with TCP_NODELAY. Send exactly eight bytes `56 50 41 44 32 00 00 00` (`VPAD2` + three NULs). Read exactly one packed 68-byte PadPacketV2. There is **no numeric version handshake**: response format/length identifies legacy versus V2. A legacy 16-byte reply followed by timeout/EOF is rejected with an update instruction.
- UDP streaming (Vita app 1.9+): connect a UDP socket to the same host, port 5001. Send `VPAD_STREAM` with its terminating NUL, **12 bytes**, every 250 ms. The Vita sends to the most recent hello's source address/port, stops after 3000 ms without hello, sends on changed input, and at least every 20 ms. The server checks samples at 1 ms intervals; this does not mean inputs sample at 1000 Hz.
- Stream packet: 4-byte ASCII `VPS1`, little-endian uint32 sequence, then 68-byte V2 body = **76 bytes**. Reject wrong size/magic, malformed fields and nonpositive signed sequence deltas; wrapping arithmetic follows the reference client.
- Keep TCP alive with V2 polls at 250 ms intervals during UDP streaming; replies are validated but not applied as input because the stream can be newer. After a one-second UDP probe with no stream, fall back to TCP polls. The reference client uses 3-second socket timeouts; VitaBridge uses bounded 1-second response and stream timeouts for safe failure, plus a 300 ms output freshness watchdog.
- TCP is a byte stream: partial replies are assembled. Sending a new request while a partial reply is outstanding would destroy framing; VitaBridge disconnects on partial-frame timeout.

### V2 body offsets (little-endian)

| Offset | Bytes | Meaning |
| --- | --- | --- |
| 0 | 4 | Vita button mask |
| 4 | 4 | lx, ly, rx, ry uint8; center 128; Y positive down |
| 8 | 2 | front and rear contact counts, each 0–2 |
| 10 | 2 | reserved |
| 12 | 12 | two front contacts: uint16 x, uint16 y, uint8 id, uint8 reserved |
| 24 | 12 | two rear contacts, same format |
| 36 | 12 | three IEEE float32 accelerometer values, G |
| 48 | 12 | three IEEE float32 gyro values, radians/s |
| 60 | 4 | process timestamp, microseconds, uint32 wraps in ~71.6 min |
| 64 | 1 | battery percentage |
| 65 | 3 | reserved |

Touch coordinates are normalized to x 0–1919, y 0–1087. Buttons: Select 1, L3 2, R3 4, Start 8, Up 0x10, Right 0x20, Down 0x40, Left 0x80, L 0x100, R 0x200, L1 0x400, R1 0x800, Triangle 0x1000, Circle 0x2000, Cross 0x4000, Square 0x8000, PS 0x10000. Remapping can generate buttons not physically present on a Vita.

Upstream documents ~250 Hz fast button reads (Unsafe Homebrew/kernel module), 60 Hz sticks/touch; actual stream rate varies. Its fake Vita sends about 200 packets/s. VitaBridge does not promise a device sampling rate. The timestamp is not synchronized with the Mac, so one-way latency cannot be measured. UI shows receive spacing, not network latency. The protocol has no authentication, encryption or integrity protection; discovery is not device authentication and a LAN peer could impersonate a Vita. Only enable injection on a trusted network.

## Original VitaPad and VitaOxiPad

[Original VitaPad](https://github.com/Rinnegatamante/VitaPad) uses TCP 5000 and a 16-byte aligned legacy PadPacket: buttons/sticks, one touch x/y, click flags, padding. It also has an alternative ExtPadPacket built from Vita SDK structures. It does not supply NG's packed V2 stream, discovery, gyro/battery schema. Its server ignores request content. VitaBridge intentionally rejects legacy input instead of interpreting it as V2. No compatibility claim for ExtPadPacket.

[VitaOxiPad](https://github.com/DvaMishkiLapa/VitaOxiPad) uses a different FlatBuffers protocol, handshake and heartbeat (server/src/net.cpp and schema), with Windows ViGEm/Linux outputs. It is not NG wire-compatible and is not supported here.

## USB identity

NG Server/kernel/usb.c defines generic Sony `054C:5650` (VitaPad) and DualShock 4 revision 2 `054C:09CC`. Generic descriptor: 14 buttons, hat, four axes; DS4 mode supplies DS4 reports, touch and motion and ignores rumble/lightbar output. A real Sony DS4 has the same DS4 identity; VID/PID alone **cannot prove it is a Vita**. UI labels candidates and reports separate GameController enumeration rather than claiming an exact cross-framework device match. IOHIDManager is opened non-exclusively. Generic known-descriptor values and GC extended gamepads are visualized; unknown generic gamepad layouts are not guessed.

## macOS virtual controller APIs

[GameController](https://developer.apple.com/documentation/gamecontroller) observes controllers; GCController snapshots are not system-wide device publication. GCVirtualController is not a macOS system-wide gamepad solution.

[Apple virtual-HID entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.hid.virtual.device) and the installed public SDK `IOKit/hidsystem/IOHIDUserDevice.h` explicitly require `com.apple.developer.hid.virtual.device` to create IOHIDUserDevice. The API is available from macOS 10.15. CoreHID `HIDVirtualDevice` is public from macOS **15** (confirmed in the installed SDK Swift interface), so cannot be the only backend for a macOS 14 app. A boolean in an ad-hoc signature does not grant a restricted entitlement. Distribution needs Apple authorization and matching provisioning/signing. DriverKit is a separately entitled system extension route, not an administrator-free shortcut.

[OpenJoystickDriver](https://github.com/xsyetopz/OpenJoystickDriver) uses IOHIDUserDevice with distinct SDLCompatible (Xbox Adaptive identity), GameControllerCompatible (Xbox Wireless identity), and Generic profiles, descriptors and SDL mapping export/launch environment. Publishing a HID device alone is not evidence of recognition by GameController or SDL. Its publisher code checks authorization and handles creation failure. [SteamControllerBridgeMac](https://github.com/runzerobass/SteamControllerBridgeMac) uses CoreHID HIDVirtualDevice and a report stream; [steam-controller-bridge](https://github.com/tkubicz/steam-controller-bridge) reports ad-hoc restricted-entitlement launch failure and distinguishes IOHID enumeration, GC recognition and SDL tests. Their claimed results are external evidence, **not VitaBridge verification**. Security-lowering procedures in that repository are deliberately not followed.

VitaBridge ships no restricted entitlement and no purported virtual gamepad. The backend is unavailable with the exact provisioning blocker. To enable legitimately later: obtain Apple entitlement authorization, add provisioned signing, implement bounded report dispatch/get/set handlers and neutral teardown, then verify each supported OS and SDL/GC consumer independently. Native USB and keyboard/mouse remain usable.

## Licensing audit

| Project | License found at inspected revision | Reuse decision |
| --- | --- | --- |
| VitaPad-NG | No root LICENSE/COPYING found; bundled client libraries have their own notices | No code/firmware/simulator redistribution; independent protocol implementation; fetch test simulator separately |
| VitaPad | No root LICENSE/COPYING found | No source redistribution |
| VitaOxiPad | Happy Bunny (modified MIT) | Inspected only; no code copied |
| OpenJoystickDriver | MIT, Krystian J. | Inspected only; no code copied |
| SteamControllerBridgeMac | MIT, Arvind Rao | Inspected only; no code copied |
| steam-controller-bridge | MIT, Lynxware | Inspected only; no code copied |

Absence of a license is not permission to redistribute. Users obtain VitaPad-NG themselves; this repository contains an original loopback simulator and a script to fetch an exact upstream revision for local integration testing.
