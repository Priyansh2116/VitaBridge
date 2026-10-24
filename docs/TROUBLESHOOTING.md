# Troubleshooting

## No Vita found

Open VitaPad-NG on the Vita, select Wi-Fi, and join the same private LAN. Guest isolation, VPN routes and broadcast filtering can block discovery. Try the private IPv4 shown on the Vita. Public/IPv6 destinations are rejected intentionally. Enable Local Network permission for VitaBridge if your macOS version asks. Do not forward ports on the router. Normal app mode is a client, not a public controller server.

## Unsupported legacy / connection timeout

Original VitaPad and VitaOxiPad are not supported. Use NG firmware with the V2 packet. The V2 request is eight bytes; an old 16-byte reply is rejected after a bounded receive timeout. TCP failure messages retain the local error category. A connected status means format-compatible packets were received, not authenticated hardware identity.

## Demo or fake Vita cannot bind

VitaBridge's built-in demo uses loopback **15000/15001**. Close another demo/test runner using these ports. The original upstream fake Vita normally binds **5000/5001**; macOS AirPlay Receiver often already owns 5000. VitaBridge's integration harness runs the unmodified upstream source in memory with its port globals redirected to 15000/15001. This avoids changing system settings and does not change packet bytes. Real hardware still uses the required 5000/5001 on the Vita.

If testing upstream manually on original port 5000, check port ownership with `lsof -nP -iTCP:5000`. Use another test host or deliberately change your own AirPlay Receiver setting through System Settings if desired; VitaBridge never disables it. Do not stop unrelated system processes to run tests.

## Inputs visible but no keys or mouse

Choose Keyboard / Mouse and an active mapping profile (Standard Gamepad intentionally contains no keyboard mappings). Read and grant Accessibility in Settings, then click Enable again. Focus the target app. Injection never enables itself on launch, backend/profile changes or wake. USB mode should receive native gamepad input directly; Wi-Fi mapping is intentionally separate.

Ad-hoc rebuilds can change the binary identity and invalidate a previous Accessibility approval. Remove/re-add the packaged app in Privacy & Security if needed, or sign consistently with your own identity. Some games ignore CGEvent input; use native USB if appropriate. Secure input/password fields may suppress injection.

If output cannot start its release helper, run the `.app` bundle from the build products, verify it has not been partially moved, and rebuild. The helper is the same executable launched before AppKit initialization; it does not require a separate installer or admin privileges. Child release-event permission inheritance remains a required acceptance check.

## Held input or output pause

The normal reset paths release all keys owned by the mapping engine; another physical key or application can independently keep a key down. Pause from the menu bar or disconnect. Freshness timeout is 300 ms; the independent helper releases on parent EOF or 600 ms without heartbeat. Press/release the affected physical key if macOS or the target app rejects release events.

A helper audit test verifies decisions and process lifecycle, not Accessibility authorization. Both processes being killed, OS crash, sleep before event delivery, or revoked permission can defeat software release. Do not claim absolute crash guarantees. The app remains paused after wake until you enable it again.

## USB shows in HID but not GameController

Generic HID and GameController support differ. Try VitaPad-NG's DualShock 4 mode with a data cable. VitaBridge's inventory shows both identities and reports GameController-visible names separately. DS4 VID/PID cannot uniquely distinguish a Vita from a Sony DS4. Raw IOHID observation may be permission-restricted; GameController observation can still work. The app never takes exclusive ownership.

## Profile import rejected

Only version 1 JSON profile arrays exported by VitaBridge are accepted. Files must be at most 1 MiB, contain 1–100 unique profiles, valid key/mouse codes and finite bounded calibration/settings. Invalid data is rejected instead of applied. A corrupt startup file is retained; export a copy before deliberately saving defaults over it.

## Virtual gamepad unavailable

This is an explicit distribution/authorization boundary. No restricted entitlement is embedded, and ad-hoc signing cannot grant one. No wireless system controller is created. Use keyboard/mouse or native USB while legitimate Apple provisioning and separate consumer verification are pursued.

## Start acts as R1 / wrong Astris action

A maintainer reported this with native USB input. First verify the physical button in VitaBridge's native Controller Test without touching the front/rear panels, since NG can map touch corners to extra shoulder/stick buttons. Check the VitaPad-NG remap menu (L + R + Start); Start should send Start, not R1. Triangle resets all firmware mappings, and Start saves. Review any existing macOS per-app controller profile and Astris input assignment too. Reconnect/restart the consumer after a change and test again.

No fix has been confirmed for that report. If Start still appears as R1, record the NG version, USB mode, macOS version and native test result in an issue. Do not blindly remap the real R1 control to compensate, and do not assume a game's + mapping from button labels alone. VitaBridge's keyboard profile editor does not alter native USB input.
