# Tested environment and limits

Original working installation verified on 2026-10-17:

| Component | Version/environment |
| --- | --- |
| OS/session | CachyOS/Arch x86_64_v4, Niri Wayland, systemd user session |
| Quickshell | 0.3.2-1.1, stock package; package integrity check: 123 files, 0 altered |
| Qt | qt6-base 6.12.0-3; qt6-declarative 6.12.0-1.1 |
| Noctalia | 5.2.1-1.1, stock; Ayu Dark theme |
| MATE Polkit | 1.28.1-4.1 |
| Gaze | gaze-bin / gaze-gui-bin 0.3.10-1 |
| Python runtime | 3.14.8-1 |
| Animation rebuild | Python 3.12.15, NumPy 2.5.4, Pillow 13.0.0, uv.lock |
| Hardware | Ryzen 9 9955HX; UGREEN CM973 FineCam 4K RGB camera, CPU inference |

Manual checks of the source used for this project:

- Real `pkexec --disable-internal-agent /usr/bin/true` face authentication succeeded.
  The user confirmed it waited for Allow/Enter after Face verified.
- A separate real prompt succeeded using Sign-in options → Password.
- Killing the Hello agent started the maintained MATE fallback; starting Hello
  again registered it successfully.
- Noctalia color/font/radius updates, all dialog states, the menu, and enlarged Tux
  rendering were inspected. Bottom corners were checked for transparent pixels.
- The animation was checked at eight poses and between two recorded keyframes;
  success holds its final pose rather than looping.

The extracted project adds portable paths, vendored icon-font lookup, optional
preview captures, and setup/build scripts. Its automated checks run separately;
creating the repository does not redeploy or restart the known working agent.

Project verification: 7 Python tests and 12 Qt test results passed; offline build
and bundled preview loaded successfully. Rebuilding the animation with the locked
dependencies reproduced the committed SHA-256 exactly.

Limitations: this is a personal prototype, not audited. Face recognition is
Gaze/PAM's responsibility. The UI relies on exact English Gaze 0.3.10 messages;
upstream wording/localization changes require review. Confirmation must be enabled
in Gaze; otherwise PAM may complete before a confirmation UI can intervene.
Stock Quickshell omits PolkitDetails, so full executable/command details and an
identity-selection UI are not implemented. Requests requiring a different admin
identity have not been tested. No system-wide authorization rules are added.

Only Wayland/Niri is tested, not an X11 MATE desktop, greeters, remote sessions,
lockers, or other distributions' PAM layouts. RGB-only facial recognition does
not gain Windows Hello's IR/depth hardware guarantees from this UI. Gaze's
liveness/model settings remain external. The face-success label means a pending
PAM confirmation, not that authorization has already been granted.
