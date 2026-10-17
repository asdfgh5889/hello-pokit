# Notice and third-party assets

This project was vibe-coded with OpenAI Codex for personal use only. It has not
received an independent security audit. No blanket open-source license is asserted
for the complete project or its reference-derived animation. The personal-use
statement does not grant rights to third-party material or replace its licenses.

- `assets/linux.svg` and the embedded path in `qml/LinuxMark.qml` come from
  Simple Icons (Linux/Tux), CC0-1.0. The original notice is retained in
  `licenses/simple-icons-CC0.md`. The icon is recolored and scaled at runtime.
- `assets/fonts/noctalia-tabler.ttf` is the icon font shipped by Noctalia 5.2.1,
  based on Tabler Icons. Copyright 2020–2025 Paweł Kuna; MIT notice retained in
  `licenses/tabler-MIT.txt`. It is vendored so the same icon glyphs work without
  depending on a distribution-specific Noctalia asset path.
- `assets/default-palette.json` and the built-in fallback colors follow Noctalia's
  Ayu Dark palette. Noctalia is an external dependency; its application code is
  not vendored or patched here.
- `qml/HelloMotion.js` contains reconstructed vector geometry derived from a
  recording of Windows Hello, credited by Windows Latest to Microsoft / Xeno.
  It is not a portable animation extracted from Microsoft binaries. The final
  Windows-logo transition is replaced by Tux. No redistribution license for the
  recording or the underlying Microsoft design is claimed. Reference URLs,
  hashes, and the reconstruction method are documented in `REFERENCES.md` and
  `docs/REPRODUCING.md`; the recording and Windows binaries are not committed.
- Quickshell, Qt, Gaze, Polkit, MATE Polkit, Python, NumPy, Pillow, and uv remain
  separate dependencies under their respective upstream licenses. A lock file
  pins optional analysis dependencies; it does not vendor their code.

This project is not affiliated with Microsoft, MATE, Noctalia, Quickshell, or Gaze.
