# Set up the Vita

You need a PS Vita that already supports homebrew and a VitaPad-NG VPK obtained from [its upstream project](https://github.com/bclarke123/VitaPad-NG). VitaBridge does not install, modify or bundle homebrew or provide console modification instructions. The original VitaPad and VitaOxiPad network formats are not supported.

Read the upstream README for your exact firmware release. The inspected NG release documents **Enable Unsafe Homebrew** in HENkaku settings: its small kernel module captures the PS button, enables USB device operation and fast button reads. This is a Vita setting, not permission to weaken macOS security. Never disable SIP or macOS signing protections for VitaBridge.

## Which download to install

**[Download VitaPad.vpk — VitaPad-NG v1.9.2](https://github.com/bclarke123/VitaPad-NG/releases/download/v1.9.2/VitaPad.vpk)** — install on the Vita, not on your Mac.

Use **VitaPad-NG from bclarke123**, whose inspected [v1.9.2 release](https://github.com/bclarke123/VitaPad-NG/releases/tag/v1.9.2) includes `VitaPad.vpk` under Assets. Transfer that VPK to your Vita and install through VitaShell. The NG VPK includes `module/vitapad_kernel.skprx`, loaded by the app; the inspected release does not require a separate plugin entry in `tai/config.txt`.

`carlelieser/vitapad` is a different USB project with a separate `.skprx` installation procedure. Its files and settings are not interchangeable with this NG setup. Do not combine similarly named plugins based on the shared name.

## Wi-Fi

1. Install the NG VPK through your existing homebrew package manager (for example VitaShell) and open VitaPad on the Vita.
2. Enable Wi-Fi and join the same trusted private LAN as the Mac. Avoid guest Wi-Fi with client isolation and networks you do not control.
3. Hold **L + R + Start** for roughly one second to open the NG remap menu. Choose **Connection → Wi-Fi**, then press Start to save/close.
4. Keep VitaPad open. Note the private IPv4 address on its screen.
5. In VitaBridge choose Discover, or enter that address and Connect. The dashboard should show UDP streaming for NG app 1.9+. Earlier V2 NG firmware uses TCP polling automatically.
6. Test all controls before enabling keyboard/mouse output. Vita remappings apply before VitaBridge sees input. Opening the Vita remap menu produces neutral input.

The Mac initiates TCP to port 5000 and UDP to 5001; discovery broadcasts on UDP 5000. There is no port forwarding and no internet remote-control service. A single most-recent UDP hello target is supported by the Vita; close other VitaPad clients.

## Native USB DualShock 4

1. Enable NG's documented Unsafe Homebrew support.
2. Open the remap menu: **L + R + Start**.
3. Choose **Connection → USB, as a DualShock 4**, then Start.
4. Connect the Vita with a data-capable USB cable. Its screen should say USB mode is connected.
5. In VitaBridge, use native USB diagnostics and enable **Show native USB / GameController input** on Controller Test. The OS USB identity is Sony `054C:09CC`.
6. Leave VitaBridge injection paused. Games receive the native USB controller directly. Open a game's controller test or Steam's controller settings to check that specific application.

PS capture and the LiveArea exit gesture depend on NG settings: upstream defaults to double-tap PS, with a configurable hold alternative. Leaving VitaPad causes its USB watchdog to remove the controller and restore normal USB after a short delay. Reopen it to reconnect.

## Generic USB gamepad

Select **Connection → USB, as a standard gamepad** instead. The expected identity is `054C:5650`, product VitaPad, with 14 buttons, a D-pad hat and two sticks. Some SDL/emulator clients may require mapping once. GameController may not expose arbitrary generic gamepads; its absence does not prove the USB HID device is broken.

USB device mode is not available on PS TV according to NG. Rumble/lightbar commands are ignored by the inspected firmware. Rear touch and motion in DS4 mode depend on the receiving game's support and are hardware checks, not verified VitaBridge capabilities.
