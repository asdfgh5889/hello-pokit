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

Project verification: 7 Python tests and 36 Qt test results passed; offline build
and bundled preview loaded successfully. Rebuilding the animation with the locked
dependencies reproduced the committed SHA-256 exactly.

Limitations: this is a personal prototype, not audited. Face recognition is
Gaze/PAM's responsibility. The UI relies on exact English Gaze 0.3.10 messages;
upstream wording/localization changes require review. Confirmation must be enabled
in Gaze; otherwise PAM may complete before a confirmation UI can intervene.
Stock Quickshell omits PolkitDetails, so full executable/command details are not
implemented. An identity selector is present; requests requiring a different admin
identity have not been tested end to end. No system-wide authorization rules are
added.

Only Wayland/Niri is tested, not an X11 MATE desktop, greeters, remote sessions,
lockers, or other distributions' PAM layouts. RGB-only facial recognition does
not gain Windows Hello's IR/depth hardware guarantees from this UI. Gaze's
liveness/model settings remain external. The face-success label means a pending
PAM confirmation, not that authorization has already been granted.

## Consent and challenge fixes (2026-10-17)

The production `AuthConversation`, `AuthResponseField`, and `AuthSubmitButton`
components have regression coverage for held/repeated Enter, keypad Enter and
Space, press/release consent, stale verification tokens, identity/request/retry
changes, cancellation/completion, draft clearing before echo-on transitions,
password-selection restrictions, and mouse presses spanning a challenge change.
A separate hidden mock-backend run injected native Qt key events into the full
Quickshell dialog's card, response field, and Allow button. All three rejected
repeats and accepted a fresh press/release. No real credentials were used.

The updated installed agent registered successfully. A real Polkit request first
completed through password fallback after Gaze timed out; a second request
completed through face authentication. The user confirmed that Face verified
waited for a fresh Enter press/release or Allow click before succeeding. The
installed security components match the tested project sources byte for byte.

These changes address frontend findings 2, 3, and 4 from the security review. They
do not resolve the upstream Quickshell request-queue concern or installer rollback
finding. Clearing input is not a guarantee of secure memory erasure.

## Immediate password selection (2026-10-17)

The local Polkit PAM entry was changed from sequential Gaze to
`auth sufficient pam_gaze.so simultaneous`, preserving the surrounding
distribution stack and elevation confirmation. The optional explicit setup helper
backs up the original PAM file; the user installer does not invoke it.

The UI now preserves a selected password draft when a same-challenge face-success
or fallback informational message arrives. Real prompt, echo, identity, request,
and retry boundaries still clear drafts. Selecting Password never submits an
empty face confirmation; a nonempty response goes through Gaze's password handoff
to the distribution stack.

Validation: 7 Python checks and 40 Qt checks passed. New regression cases cover
password selection during scanning, preserving a draft across late face success
and scan failure, and clearing at actual challenge changes. The installed
`AuthConversation.qml` matches the tested source byte for byte.

A real `/usr/bin/true` Polkit request exposed a pending response while scanning
59 ms after launch. The dialog subsequently waited in face-confirmation state;
the user selected Password and confirmed that password authentication succeeded.
The command exited 0. Clicking the selector alone does not stop Gaze's camera
task; submitting the password bypasses the biometric path.
