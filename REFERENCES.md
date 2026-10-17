# References and provenance

Sources retained for the implementation and preceding UI/animation investigation.
Upstream dependencies are used unpatched. Research downloads, candidate patches,
and Windows binaries are not part of the repository. Links describe sources,
not endorsements or redistribution permissions; see [NOTICE](NOTICE.md).

## Authentication and stock Quickshell backend

- [Quickshell 0.3.2 Polkit module](https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.Polkit/),
  [PolkitAgent](https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.Polkit/PolkitAgent/),
  [AuthFlow](https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.Polkit/AuthFlow/):
  registration, PAM conversation state, submission, and cancellation.
- Quickshell 0.3.2 source reviewed:
  [flow.hpp](https://git.outfoxxed.me/quickshell/quickshell/src/tag/v0.3.2/src/services/polkit/flow.hpp),
  [flow.cpp](https://git.outfoxxed.me/quickshell/quickshell/src/tag/v0.3.2/src/services/polkit/flow.cpp),
  [listener.hpp](https://git.outfoxxed.me/quickshell/quickshell/src/tag/v0.3.2/src/services/polkit/listener.hpp),
  [listener.cpp](https://git.outfoxxed.me/quickshell/quickshell/src/tag/v0.3.2/src/services/polkit/listener.cpp),
  [agentimpl.cpp](https://git.outfoxxed.me/quickshell/quickshell/src/tag/v0.3.2/src/services/polkit/agentimpl.cpp).
  The stock listener does not expose PolkitDetails to QML. A proposed metadata
  patch was declined and is neither included nor required.
- Quickshell [Process](https://quickshell.org/docs/v0.3.2/types/Quickshell.Io/Process/),
  [FileView](https://quickshell.org/docs/v0.3.2/types/Quickshell.Io/FileView/),
  [PanelWindow](https://quickshell.org/docs/v0.3.2/types/Quickshell/PanelWindow/),
  [IpcHandler](https://quickshell.org/docs/v0.3.2/types/Quickshell.Io/IpcHandler/),
  [Wayland types](https://quickshell.org/docs/v0.3.2/types/Quickshell.Wayland/):
  theme helper, watched palette, layer-shell dialog, and local status/preview IPC.
- Polkit [pkexec manual](https://polkit.pages.freedesktop.org/polkit/pkexec.1.html),
  [Polkit manual](https://polkit.pages.freedesktop.org/polkit/polkit.8.html),
  [pkexec source](https://github.com/polkit-org/polkit/blob/main/src/programs/pkexec.c),
  [command abbreviation change](https://cgit.freedesktop.org/polkit/commit/?id=322c014ccf21db7cd223192fa237178645c492e6):
  request messages, action identity, graphical tests, and command-detail limits.
- [MATE Polkit](https://github.com/mate-desktop/mate-polkit): maintained fallback
  agent. Its executable is launched as a separate service; no MATE code is forked.
- systemd [service](https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html),
  [unit](https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html),
  [execution](https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html):
  user units, OnFailure, conflicts, environment, and executable argument quoting.

## Gaze/PAM and earlier alternatives

- [Gaze v0.3.10](https://github.com/GunduLabs/gaze/tree/v0.3.10), source review at
  commit `a353489eafe5e267b93adec148f8e6f294563d4a`.
- Its [PAM guide](https://github.com/GunduLabs/gaze/blob/v0.3.10/docs/src/guide/pam.md),
  [configuration](https://github.com/GunduLabs/gaze/blob/v0.3.10/docs/src/guide/configuration.md),
  [installation](https://github.com/GunduLabs/gaze/blob/v0.3.10/docs/src/guide/installation.md),
  [how it works](https://github.com/GunduLabs/gaze/blob/v0.3.10/docs/src/guide/how-it-works.md),
  [CLI](https://github.com/GunduLabs/gaze/blob/v0.3.10/docs/src/guide/cli.md),
  and [comparison](https://github.com/GunduLabs/gaze/blob/v0.3.10/docs/src/guide/comparison.md).
- Gaze PAM [core.rs](https://github.com/GunduLabs/gaze/blob/v0.3.10/crates/pam-gaze/src/core.rs)
  and [auth.rs](https://github.com/GunduLabs/gaze/blob/v0.3.10/crates/pam-gaze/src/auth.rs):
  exact face-confirmation/fallback messages and sequential versus simultaneous behavior.
- [hyprpolkitagent](https://github.com/hyprwm/hyprpolkitagent), its
  [usage/configuration](https://wiki.hypr.land/Hypr-Ecosystem/hyprpolkitagent/), and
  [hyprtoolkit theming](https://wiki.hyprland.org/Hypr-Ecosystem/hyprtoolkit/):
  alternative UI surveyed before choosing this custom frontend.
- [Hyprlock](https://github.com/hyprwm/hyprlock) and its
  [documentation](https://wiki.hypr.land/Hypr-Ecosystem/hyprlock/): earlier separate
  lock-screen investigation, not a runtime component or configuration in this project.
- [Howdy](https://github.com/boltgolt/howdy): earlier face-authentication alternative;
  not used in this implementation.

## Noctalia theme and icons

- [Noctalia v5.2.1](https://github.com/noctalia-dev/noctalia/tree/v5.2.1),
  [theme templates](https://github.com/noctalia-dev/noctalia/blob/v5.2.1/docs/user/theming/templates.mdx),
  [app theming](https://github.com/noctalia-dev/noctalia/blob/v5.2.1/docs/user/theming/app-theming.mdx).
- Noctalia [configuration schema](https://github.com/noctalia-dev/noctalia/blob/v5.2.1/src/config/schema/config_schema.cpp),
  [style.h](https://github.com/noctalia-dev/noctalia/blob/v5.2.1/src/ui/style.h),
  [style.cpp](https://github.com/noctalia-dev/noctalia/blob/v5.2.1/src/ui/style.cpp),
  [config service](https://github.com/noctalia-dev/noctalia/blob/v5.2.1/src/config/config_service.cpp),
  [built-in palettes](https://github.com/noctalia-dev/noctalia/blob/v5.2.1/src/theme/builtin_palettes.cpp):
  font family, radius scale, 6/9/12px radii, and Ayu Dark fallback colors.
- Noctalia [icon font](https://github.com/noctalia-dev/noctalia/blob/v5.2.1/assets/fonts/noctalia-tabler.ttf)
  and [font license](https://github.com/noctalia-dev/noctalia/blob/v5.2.1/assets/fonts/tabler-icons-license.txt),
  derived from [Tabler Icons](https://github.com/tabler/tabler-icons), MIT.
  The matching font and notice are vendored to preserve private-use glyph mappings.
- Simple Icons [Linux SVG](https://github.com/simple-icons/simple-icons/blob/develop/icons/linux.svg),
  [raw input](https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/linux.svg),
  [CC0 license](https://github.com/simple-icons/simple-icons/blob/develop/LICENSE.md).
  Exact input is committed as `assets/linux.svg`; its hash is in reproduction docs.

## Windows Hello design and motion

- Microsoft [Windows 11 Insider build 27754 announcement, 2024-11-20](https://blogs.windows.com/windows-insider/2024/11/20/announcing-windows-11-insider-preview-build-27754-canary-channel/)
  and [static Hello asset](https://blogs.windows.com/wp-content/uploads/prod/sites/44/2024/11/Hello-static-asset.png):
  original design reference. User-supplied Windows Security/passkey screenshots
  guided layout, method selection, and confirmation; private screenshot files are not committed.
- Mayank Parmar, Windows Latest,
  [Windows 11 KB5045889 tests modern UI for security, 2024-11-02](https://www.windowslatest.com/2024/11/02/windows-11-kb5045889-tests-modern-ui-for-security-hides-bell-icon-on-taskbar/),
  and its [actual UI animation recording](https://www.windowslatest.com/wp-content/uploads/2024/11/Windows-Hello-new-animation.gif).
  The article credits the GIF to Microsoft / Xeno. This recording is the
  hash-checked tracing input, not a transparent animation asset. Vector output,
  reconstruction scripts, hashes, timing, and the Tux substitution are documented
  in [REPRODUCING.md](docs/REPRODUCING.md).
- Community recreations surveyed, **not copied into this implementation**:
  [Bhakti Pasaribu's SVG/GSAP recreation](https://codepen.io/pasaribu/pen/VvVebO),
  [zippy36jr mirror](https://gist.github.com/zippy36jr/083ddccf04d1327d683f19b701654e4d),
  [manux7 fork](https://codepen.io/manux7/pen/EVMGbZ).
- [Winbindex](https://winbindex.m417z.com/) metadata and Microsoft's public
  [symbol server](https://msdl.microsoft.com/download/symbols/): original Windows
  DLLs were inspected as data, never executed, while looking for a reusable asset.
  `AnimatedVisuals.HelloSolidAnimations` and FaceStart/FaceLoop/FaceSuccess/FaceFail
  strings were found in compiled Windows components; the examined files did not
  yield a standalone portable animation. Exact five download URLs, versions, and
  SHA-256 values are in
  [windows-binary-provenance.json](docs/research/windows-binary-provenance.json).
  None of these DLLs is needed to build or run this project.

## Rendering, helpers, and build tooling

- Qt [key handling](https://doc.qt.io/qt-6/qml-qtquick-keys.html),
  [QKeyEvent auto-repeat](https://doc.qt.io/qt-6/qkeyevent.html#isAutoRepeat),
  [TextInput echo/masking](https://doc.qt.io/qt-6/qml-qtquick-textinput.html),
  [Rectangle](https://doc.qt.io/qt-6/qml-qtquick-rectangle.html),
  [Shape](https://doc.qt.io/qt-6/qml-qtquick-shapes-shape.html),
  [ShapePath](https://doc.qt.io/qt-6/qml-qtquick-shapes-shapepath.html),
  [PathSvg](https://doc.qt.io/qt-6/qml-qtquick-pathsvg.html),
  [NumberAnimation](https://doc.qt.io/qt-6/qml-qtquick-numberanimation.html),
  [Qt Quick Test](https://doc.qt.io/qt-6/qtquicktest-index.html),
  [TestCase](https://doc.qt.io/qt-6/qml-qttest-testcase.html):
  vector rendering, smooth playback, explicit bottom corner radii, offscreen tests.
- Linux [inotify](https://man7.org/linux/man-pages/man7/inotify.7.html),
  Python [ctypes](https://docs.python.org/3/library/ctypes.html) and
  [tomllib](https://docs.python.org/3/library/tomllib.html): theme-change helper.
- [NumPy](https://numpy.org/doc/stable/), [Pillow](https://pillow.readthedocs.io/),
  [uv lock files](https://docs.astral.sh/uv/concepts/projects/sync/): optional
  offline-reference analysis, contour processing, and dependency locking.
