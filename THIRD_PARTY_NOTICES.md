# Third-party notices and attribution

VitaBridge independently implements the VitaPad-NG wire format and uses public macOS frameworks. No external Swift package dependencies, firmware binaries, copied upstream source, HID descriptors, console artwork or upstream simulator source are included in this repository or app. The MIT license applies to original VitaBridge material only.

| Project | Relationship | License found at inspected revision |
| --- | --- | --- |
| [VitaPad-NG](https://github.com/bclarke123/VitaPad-NG) | Protocol interoperability; user separately installs its VPK; simulator separately fetched for local tests | No root redistribution license found |
| [Original VitaPad](https://github.com/Rinnegatamante/VitaPad) | Legacy protocol comparison; not wire-compatible with this receiver | No root redistribution license found |
| [VitaOxiPad](https://github.com/DvaMishkiLapa/VitaOxiPad) | Alternate protocol research | Happy Bunny / modified MIT |
| [OpenJoystickDriver](https://github.com/xsyetopz/OpenJoystickDriver) | Public macOS virtual-HID API and consumer profile research | MIT |
| [SteamControllerBridgeMac](https://github.com/runzerobass/SteamControllerBridgeMac) | CoreHID implementation research | MIT |
| [steam-controller-bridge](https://github.com/tkubicz/steam-controller-bridge) | Virtual-HID feasibility and recognition research | MIT |

Exact inspected revisions and technical findings are in [UPSTREAM_REVISIONS](docs/UPSTREAM_REVISIONS.md) and [RESEARCH](docs/RESEARCH.md). The upstream simulator fetch script does not license or redistribute its source; it retrieves it separately for local testing. Do not add that source, homebrew binaries or their build artifacts to a VitaBridge release without verifying permission.

Apple frameworks and SDKs are supplied by macOS/Xcode under their respective terms. Sony, PlayStation, PS Vita, DualShock, Apple, macOS, Nintendo and Steam names are used only to describe interoperability; no affiliation or endorsement is implied.
