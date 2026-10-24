# Security

VitaBridge receives input using VitaPad-NG's unauthenticated LAN protocol. Discovery replies are not device authentication. Only connect on a trusted private network, and explicitly enable keyboard/mouse output when you intend to control the focused app. No internet service or port forwarding is required. The app does not automatically request Accessibility permission.

Input release is best-effort: disconnect/pause resets, a freshness timeout and an independent helper reduce stuck-input risk, but cannot guarantee recovery after OS failure, both processes being killed or permission revocation. See [architecture](docs/ARCHITECTURE.md).

For a vulnerability, use the repository's private security-reporting option if enabled. Otherwise open an issue requesting a private reporting channel without publishing exploit details, credentials or sensitive diagnostics. Do not post personal profiles, public/private IP addresses, signing identities, tokens, console keys or full desktop screenshots. Enable GitHub private vulnerability reporting when administering the repository.
