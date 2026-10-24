# Contributing

VitaBridge targets macOS 14+ and Swift 6. Open the committed Xcode project or use the dependency-free Swift package. XcodeGen 2.45.4 was used for generation; run `xcodegen generate` after editing `project.yml`, and include the generated project diff.

## Local checks

```sh
./scripts/test-upstream.sh
xcodebuild -project VitaBridge.xcodeproj -scheme VitaBridge \
  -destination 'platform=macOS' -derivedDataPath build test
./scripts/package-release.sh
```

Python 3 is needed for the separately fetched upstream simulator and helper audit. Stop any other demo/test server first. Only edit within this repository; generated build outputs, profiles, signing assets and simulator checkouts must stay out of commits.

## Pull requests

Describe the concrete problem, resulting behavior and relevant checks. Keep protocol parsing, transport, mapping, output and UI responsibilities separate. Add meaningful regression coverage for behavior changes, especially partial TCP frames, malformed packets, sequence wrapping, shared-key release and disconnect handling. UI/documentation changes do not need tests that duplicate their implementation.

Label evidence accurately: automated fixture/simulator, maintainer-reported hardware, or independently reproduced consumer/hardware test. Provide macOS, VitaPad-NG, device, transport and consumer versions when reporting compatibility. Never infer that HID enumeration proves GameController or SDL recognition. No changes that bypass SIP, signing, entitlement gates or permission prompts.

The original VitaPad and other similarly named homebrew projects are not VitaPad-NG. Link the exact upstream and inspect licensing before adding third-party material. No firmware, ROMs, keys, personal configurations or unlicensed source belongs in a contribution.

Contributions to original VitaBridge material are offered under this repository's MIT license. Third-party ownership and license requirements remain separate.
