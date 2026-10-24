# Publishing VitaBridge

The repository is prepared for GitHub source publication. Its original material uses MIT; upstream firmware/simulator code is not covered or bundled. Review the README, [license](../LICENSE), [third-party notices](../THIRD_PARTY_NOTICES.md) and compatibility record before publishing. A local commit or ZIP is not an online publication.

## Repository contents

Publish source, tests, `VitaBridge.xcodeproj`, `project.yml`, scripts and documentation. Do not commit `build`, `.build`, `dist`, personal profiles, signing identities, provisioning profiles, firmware, homebrew plugins, simulator checkouts or unrelated parent-directory files. `.gitignore` excludes common generated and sensitive formats.

The initial preparation found a parent Git repository outside the project; VitaBridge now has its own repository. Confirm before adding files:

```sh
git rev-parse --show-toplevel
git status --short
```

The top level must be the VitaBridge project directory. Never run a publication command from the parent repository.

## Local checks

```sh
./scripts/test-upstream.sh
xcodebuild -project VitaBridge.xcodeproj -scheme VitaBridge \
  -destination 'platform=macOS' -derivedDataPath build test
./scripts/package-release.sh
```

The package script builds arm64 and x86_64, verifies the app signature, runs the independent helper in audit mode, and produces:

- `dist/VitaBridge-macOS-universal.zip`
- `dist/SHA256SUMS`

The ZIP is an **ad-hoc development build**, not a Developer ID signed/notarized consumer release. It does not bundle firmware or the upstream simulator. Its existence is not proof of game compatibility or Accessibility permission acceptance.

## Create a GitHub repository

Use an authenticated GitHub connection, GitHub Desktop, or the GitHub CLI. If using the CLI, install it through its official instructions, then authenticate interactively:

```sh
gh auth login
```

Do not paste access tokens into this repository, chat, issue or shell script. Replace `YOUR_GITHUB_USER` below with the intended account. Use `--private` instead of `--public` if desired. These commands create a new remote and publish the current project:

```sh
# Only if the initial project commit has not already been made:
git add .github .gitignore CHANGELOG.md CONTRIBUTING.md Config LICENSE \
  Package.swift README.md SECURITY.md Sources Tests THIRD_PARTY_NOTICES.md \
  VitaBridge.xcodeproj docs project.yml scripts
git diff --cached --check
git diff --cached --stat
git commit -m "Prepare VitaBridge for publication"

# Publish the new repository:
gh repo create YOUR_GITHUB_USER/VitaBridge --public --source=. --remote=origin --push
```

Review Git's configured author email before committing; GitHub offers a no-reply address if you prefer not to publish a personal email. If the destination repository already exists, inspect its history first and connect it deliberately. Do not use force-push to overwrite it.

After push, inspect the Actions tab. Hosted CI has only been configured until an actual successful hosted run is recorded. The workflow needs read-only repository contents, fetches upstream test source separately, and uploads the development ZIP/checksum as a short-lived build artifact. No signing secrets are needed for this path. Add repository topics such as `macos`, `swift`, `swiftui`, `psvita`, `game-controller`, and `homebrew`, and enable private security reporting if available.

## Draft release

After hosted checks pass and documentation reflects the tested commit, create a draft release. For example, with a reviewed `v1.0.0` tag and release-notes file:

```sh
gh release create v1.0.0 \
  dist/VitaBridge-macOS-universal.zip dist/SHA256SUMS \
  --draft --title "VitaBridge v1.0.0" --notes-file RELEASE_NOTES.md
```

Prepare `RELEASE_NOTES.md` for the actual tested release before running that command. Label unsigned/ad-hoc artifacts accurately; do not represent them as notarized. Update CHANGELOG, MARKETING_VERSION/CURRENT_PROJECT_VERSION and the generated project deliberately when making a new version. A draft is not automatically published.

For normal public binary distribution, sign the app consistently with a valid Developer ID, notarize using Apple's supported tooling, staple the ticket, rebuild the ZIP, verify the signature/ticket and regenerate checksums. Neither restricted virtual-HID authorization nor universal game compatibility comes from Developer ID signing. Do not bypass Gatekeeper, SIP or entitlement checks.

## Source archive

A reviewed committed snapshot can be shared without generated files:

```sh
mkdir -p dist
git archive --format=zip --prefix=VitaBridge/ HEAD > dist/VitaBridge-source.zip
```

The archive includes only committed project files. It contains no Git authentication and cannot create a hosted repository by itself.
