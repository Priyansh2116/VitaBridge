# Verification record

Completed locally on 2026-10-24. Host: Apple Silicon, macOS 27.0 (26A428). Toolchain: Xcode 27.0 (27A266a), Apple Swift 6.4 compiling in Swift 6 mode. XcodeGen 2.45.4 generated the committed project. Deployment target remains macOS 14.

| Check | Result | Evidence / scope |
| --- | --- | --- |
| Universal Release app | PASS | `xcodebuild ... -configuration Release -derivedDataPath build ONLY_ACTIVE_ARCH=NO ARCHS='arm64 x86_64' clean build`; BUILD SUCCEEDED |
| Architectures | PASS | `lipo -archs` reports x86_64 and arm64; Intel runtime not exercised |
| Signature validation | PASS | `codesign --verify --deep --strict` on final app |
| Hardened runtime packaging | PASS | Internal modules are statically linked; `otool -L` shows system dependencies, no embedded private module dylibs; hardened runtime stays enabled |
| Native app launch | PASS | `open build/Build/Products/Release/VitaBridge.app`; final app remained running after launch (process verified separately). Injection starts paused. This is startup verification, not a full UI interaction test |
| SwiftPM + original upstream simulator | PASS | **23 tests, 0 skipped, 0 failures**, final run 21:53:39 local time; includes all seven upstream cases |
| Xcode XCTest runner | PASS | **23 tests, 7 skipped, 0 failures**, final static-project run 21:56:08 local time. Seven optional upstream cases skipped because Xcode test environment did not carry VITABRIDGE_FAKE_VITA; these passed separately in SwiftPM |
| Independent helper process | PASS, audit only | `python3 scripts/check-watchdog.py build/Build/Products/Release/VitaBridge.app/Contents/MacOS/VitaBridge`; pipe EOF and 600 ms stalled-parent release, no CGEvents posted |
| Real Wi-Fi Vita | NOT TESTED | No physical Vita connected |
| Native USB Vita / real games | NOT TESTED | No physical device or consumer compatibility test |
| Accessibility-authorized consumer injection | NOT TESTED | No permission was silently requested or granted; key/mouse event posting code and mapping exist, but delivery into a separate editor/game requires explicit user authorization and acceptance testing |
| Real child-helper release injection | NOT TESTED | Audit verifies decisions/process lifecycle, not inherited TCC authorization or consumer event delivery |
| macOS 14 / Intel runtime | NOT TESTED | Universal compilation is not runtime verification |
| Wireless virtual gamepad | UNAVAILABLE | No Apple-authorized restricted entitlement/provisioning; no HID publication or consumer-recognition claim |

The first launch check caught an ad-hoc dynamic-framework library-validation failure despite a valid bundle signature. The final project fixes this by static linking; no library-validation exception or macOS security change was used. The final Release helper audit and native process launch both passed after that fix.

The local AirPlay Receiver owns TCP 5000. Integration tests run upstream's exact packet implementation with only its two port globals changed in memory to 15000/15001. Normal hardware connections retain the mandated Vita ports 5000/5001. Discovery's payload and source-port checks use the selected port configuration. This is simulator protocol verification, not proof of physical network/firewall behavior.

Detailed acceptance checks are in [TESTING.md](TESTING.md) and [COMPATIBILITY.md](COMPATIBILITY.md). The permission-dependent portion of the user's MVP definition is **not claimed complete** until another app receives authorized injected events and physical hardware checks are performed.

## Build artifacts

- App: `build/Build/Products/Release/VitaBridge.app` (about 2.8 MiB in this build).
- Final build log from this session: `/private/tmp/vitabridge-release.log`.
- Full upstream test log: `/private/tmp/vitabridge-integration.log`.
- Xcode runner log: `/private/tmp/vitabridge-xcode-test.log`.
- Xcode result bundle: `/private/tmp/vitabridge-xcode/Logs/Test/Test-VitaBridge-2026.10.24_21-56-01-+0530.xcresult`.

Temporary logs/result bundles may be removed by macOS. The source, committed Xcode project, commands and this result summary remain in the repository.

## Subsequent maintainer reports

After the original build session, the maintainer reported a real Vita connecting over Wi-Fi, followed by USB input appearing in native testing and Astris. This is useful **maintainer-reported, partial hardware evidence**, separate from the automated results above. Exact Vita model, firmware, macOS and Astris versions were not recorded.

A USB test reported the Vita's Start button appearing as R1, with an unintended attack action in Astris. The mapping layer responsible has not been isolated and the suggested Vita remap/reset has not been confirmed to fix it. Do not label the USB mapping, all Astris controls or general game compatibility verified. Accessibility-authorized keyboard/mouse delivery and real helper-release injection are still not confirmed.

For publication, original-code MIT licensing, attribution, contribution/issue templates, macOS CI and development ZIP packaging were added. Hosted CI is configured but must be observed after an authenticated push; no remote publication is implied by these files.

## Publication-preparation checks

The updated `scripts/test-upstream.sh` was exercised with a fresh temporary upstream checkout pinned to the inspected commit: **23 tests passed, no skips or failures**. `scripts/package-release.sh` produced a universal app, passed signature validation and the helper audit, and generated `dist/VitaBridge-macOS-universal.zip` with `dist/SHA256SUMS`. Shell syntax and local Markdown links were checked. The package remains an ad-hoc development artifact.

A project-local Git repository was initialized to isolate this source from the parent directory's repository. No remote was configured, no commit was created, and nothing was pushed. The maintainer will create/configure the GitHub repository and publish it themselves. Hosted CI remains unverified until that push.
