# Reproduction

## Normal build

`make build` uses only Python's standard library. It copies an allowlisted source
layout to `dist/hello-polkit/` and emits `MANIFEST.sha256.json`, mapping every
bundled file except the manifest itself to its content hash. This is a portable
source/runtime directory, not a native compiled binary or distribution package.
Repeated builds from the same inputs produce identical manifest contents; file
metadata is not part of the reproducibility claim. System dependencies remain
external, with tested versions recorded separately.

The root `shell.qml` is the Quickshell entry point; keep it at the bundle root
so the engine can resolve both `qml/` components and vendored `assets/`.
The bundle includes its own build/setup tools and tests. Move it to another path
and run the same Make targets from there. Neither runtime sources nor templates
contain the original username or home directory. `make install` renders actual
paths and quotes systemd arguments, including spaces, `%`, and `$` characters.
It installs only the runtime directories, notices, two units, and one Noctalia
config fragment. No secrets, face templates, or privileged configuration are copied.

## Regenerate the animation

Run `make animation` from the checkout or bundle. The reference fetcher verifies
SHA-256 before writing `.cache/reference/windows-hello.gif`. Optional analysis
dependencies are locked with uv (Python 3.12.15 in `.python-version`): NumPy 2.5.4 and Pillow 13.0.0. The normal UI does
not import either package. The two analysis scripts also accept `--input` and
`--output` for offline/local inputs or comparisons.

1. `tools/trace-reference.py` subtracts the recorded background, identifies face
   silhouettes, fits eye ellipses, and smooths contours into vector paths. It
   keeps the first 141 40ms poses, before the final Windows-logo formation.
2. `tools/interpolate-motion.py` matches seven semantic tracks (mouth, eyes,
   four frame corners), resamples/aligns contours, and emits `qml/HelloMotion.js`.
   Catmull–Rom interpolation moves between recorded poses at Qt's animation
   refresh rate instead of stepping a 25fps bitmap sequence.
3. `qml/HelloFace.qml` supplies the playback state machine. Reference timeline:
   intro 0–800ms, scan loop 800–4600ms, success 4600–6160ms. Playback is 1.25×;
   success completes once and holds Tux. Hidden/inactive animation stops.
4. `qml/LinuxMark.qml` embeds the path from `assets/linux.svg`, preserving its
   CC0 provenance while applying theme color and size. That path and the QML
   component are committed inputs; no remote SVG lookup occurs at runtime.

Known input/output SHA-256:

| File | SHA-256 |
| --- | --- |
| Reference GIF | `6cec6e88034c225609c2345bf3092beda5cbb83a6d9f8ce5f9bfc1d11638acff` |
| `assets/linux.svg` | `7e55f2779ae11a83c9dad2d0414a65d8ca7867d0716ce58bfe41ed299ae1447f` |
| `qml/HelloMotion.js` | `ff774bd9cddd8dd8d276b7f806858a8e1c9dd5aa24e789d6b4109d74b7545c3e` |

The reference recording is fetched only for this optional rebuild. It and all
Windows DLLs are excluded from the bundle and Git. Consult [NOTICE](../NOTICE.md)
before redistributing reference-derived material.

## Verification

`make test` runs isolated installation/backup/manifest/theme tests and offscreen
Qt tests for confirmation guards, held/repeated keys, challenge/identity changes,
password-to-visible-response transitions, mouse consent, fallback messages,
reference poses, interpolated motion, scan looping, and success holding. A headless
stock-Quickshell check also exercises the real monotonic clock and 15-second
face-confirmation expiry with a mock conversation. Images are saved under
`.cache/test-artifacts/`. Set `QMLTESTRUNNER=/path/to/qt6/qmltestrunner` if detection
fails. These checks never register an agent, invoke Polkit, alter the real XDG
configuration, or activate services.

For a visible source preview, `make preview`. For state inspection use:

```sh
qs --path "$PWD/shell.qml" ipc call helloPolkit status
qs --path "$PWD/shell.qml" ipc call helloPolkitPreview setState options
```

Other preview states: `scanning`, `verified`, `password`, `fallback`, `details`.
Preview IPC cannot alter a live authentication flow. Mock screenshots are opt-in;
the real agent never captures the dialog or logs a password. Live integration
checks and limits are listed in [TESTED.md](TESTED.md).
