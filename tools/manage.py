"""User-local setup. Never edits PAM, installs packages, or invokes sudo."""
import argparse
from dataclasses import dataclass
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import tomllib

ROOT = Path(__file__).resolve().parents[1]


@dataclass(frozen=True)
class Paths:
    target: Path
    units: Path
    fragment: Path
    backups: Path

    @classmethod
    def current(cls):
        home = Path.home()
        config = Path(os.environ.get("XDG_CONFIG_HOME", home / ".config")).resolve()
        state = Path(os.environ.get("XDG_STATE_HOME", home / ".local/state")).resolve()
        noctalia = Path(os.environ.get("NOCTALIA_CONFIG_HOME", config)).resolve()
        return cls(config / "quickshell/hello-polkit", config / "systemd/user",
                   noctalia / "noctalia/zz-hello-polkit.toml", state / "hello-polkit/backups")


def unit_arg(value):
    """Quote one systemd ExecStart argument, including specifier expansion."""
    value = str(value)
    if any(ord(c) < 32 for c in value):
        raise ValueError("Control characters are not supported in installation paths")
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"').replace("%", "%%").replace("$", "$$") + '"'


def render(root, name, values):
    text = (root / "templates" / name).read_text()
    for key, value in values.items():
        text = text.replace("@" + key + "@", value)
    return text


def install(root, paths, qs, mate):
    # Save the complete previous runtime and exact files before replacing any of them.
    destinations = [paths.target, paths.units / "hello-polkit.service",
                    paths.units / "mate-polkit.service", paths.fragment]
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
    backup = paths.backups / stamp
    backup.mkdir(parents=True, exist_ok=False)
    records = []
    for index, destination in enumerate(destinations):
        record = {"destination": str(destination), "saved": None}
        if destination.exists() or destination.is_symlink():
            saved = backup / str(index)
            if destination.is_dir():
                shutil.copytree(destination, saved, symlinks=True)
            else:
                shutil.copy2(destination, saved, follow_symlinks=False)
            record["saved"] = str(saved)
        records.append(record)
    (backup / "restore-map.json").write_text(json.dumps(records, indent=2) + "\n")
    staged = backup / "new-runtime"
    staged.mkdir()
    for name in ("qml", "assets", "licenses"):
        shutil.copytree(root / name, staged / name,
                        ignore=shutil.ignore_patterns("__pycache__", "*.pyc", "palette.json"))
    shutil.copy2(root / "NOTICE.md", staged / "NOTICE.md")
    shutil.copy2(root / "shell.qml", staged / "shell.qml")
    # Preserve a valid palette on upgrades; seed fresh installs with the checked-in default.
    old_palette = paths.target / "qml/palette.json"
    legacy_palette = paths.target / "palette.json"
    palette = next((p for p in (old_palette, legacy_palette) if p.is_file()), root / "assets/default-palette.json")
    shutil.copy2(palette, staged / "qml/palette.json")
    hello = render(root, "hello-polkit.service.in", {
        "QS": unit_arg(qs), "SHELL": unit_arg(paths.target / "shell.qml")})
    fallback = render(root, "mate-polkit.service.in", {"MATE": unit_arg(mate)})
    fragment = render(root, "noctalia.toml.in", {
        "INPUT": json.dumps(str(paths.target / "qml/palette.template.json")),
        "OUTPUT": json.dumps(str(paths.target / "qml/palette.json"))})
    # This stage is complete before the old runtime is removed. Backup remains on failure.
    paths.target.parent.mkdir(parents=True, exist_ok=True)
    if paths.target.is_symlink():
        paths.target.unlink()
    elif paths.target.exists():
        shutil.rmtree(paths.target)
    shutil.move(str(staged), str(paths.target))
    paths.units.mkdir(parents=True, exist_ok=True)
    paths.fragment.parent.mkdir(parents=True, exist_ok=True)
    (paths.units / "hello-polkit.service").write_text(hello)
    (paths.units / "mate-polkit.service").write_text(fallback)
    paths.fragment.write_text(fragment)
    return backup


def systemctl(*args, check=True):
    return subprocess.run(["systemctl", "--user", *args], check=check)


def status(qs, paths):
    result = subprocess.run([qs, "--path", str(paths.target / "shell.qml"), "ipc", "call",
                             "helloPolkit", "status"], capture_output=True, text=True, check=True, timeout=3)
    return json.loads(result.stdout)


def recover():
    systemctl("disable", "--now", "hello-polkit.service", check=False)
    systemctl("reset-failed", "hello-polkit.service", check=False)
    systemctl("enable", "--now", "mate-polkit.service")


def activate(qs, paths):
    if not os.environ.get("WAYLAND_DISPLAY"):
        raise SystemExit("Run activation from a terminal in the Wayland desktop session")
    if not (paths.target / "shell.qml").is_file():
        raise SystemExit("Run install first")
    noctalia = shutil.which("noctalia")
    if noctalia:
        config = subprocess.run([noctalia, "config", "export", "full"], check=True,
                                capture_output=True, text=True, timeout=5)
        if tomllib.loads(config.stdout).get("shell", {}).get("polkit_agent", True):
            raise SystemExit("Disable Noctalia's built-in Polkit agent, then retry; see docs/SETUP.md")
    names = [name for name in ("WAYLAND_DISPLAY", "DISPLAY", "XDG_SESSION_ID", "XDG_CURRENT_DESKTOP",
                               "NOCTALIA_CONFIG_HOME", "NOCTALIA_STATE_HOME", "XDG_CONFIG_HOME", "XDG_STATE_HOME")
             if os.environ.get(name)]
    systemctl("import-environment", *names)
    systemctl("daemon-reload")
    try:
        systemctl("restart", "hello-polkit.service")
        deadline = time.monotonic() + 9
        while time.monotonic() < deadline:
            try:
                state = status(qs, paths)
                if state.get("registered") and not state.get("preview"):
                    systemctl("enable", "hello-polkit.service")
                    systemctl("disable", "mate-polkit.service")
                    print("Hello Polkit registered; MATE remains the crash fallback")
                    return
            except (subprocess.SubprocessError, ValueError):
                pass
            time.sleep(0.25)
        raise RuntimeError("Polkit registration did not succeed")
    except (subprocess.SubprocessError, RuntimeError):
        recover()
        raise


def find_mate(override):
    candidates = [override] if override else [
        "/usr/lib/mate-polkit/polkit-mate-authentication-agent-1",
        "/usr/libexec/polkit-mate-authentication-agent-1",
        "/usr/lib/policykit-1-mate/polkit-mate-authentication-agent-1",
        shutil.which("polkit-mate-authentication-agent-1")]
    for candidate in candidates:
        if candidate and Path(candidate).is_file() and os.access(candidate, os.X_OK):
            return str(Path(candidate).resolve())
    raise SystemExit("MATE Polkit agent not found; install mate-polkit or pass --mate /absolute/path")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    preview = sub.add_parser("preview", help="Mock UI; never registers an authentication agent")
    preview.add_argument("--state", choices=("scanning", "verified", "password", "fallback"), default="scanning")
    preview.add_argument("--failure", action="store_true", help="Demonstrate automatic password fallback")
    preview.add_argument("--capture", action="store_true", help="Save mock-only images under .cache/previews")
    setup = sub.add_parser("install", help="Install user files and back up previous files; no activation")
    setup.add_argument("--mate", help="MATE agent executable if automatic detection fails")
    for name in ("activate", "recover", "status"):
        sub.add_parser(name)
    args = parser.parse_args()
    paths = Paths.current()
    if args.command == "recover":
        systemctl("daemon-reload")
        recover()
        return
    qs = shutil.which("qs")
    if not qs:
        raise SystemExit("Stock Quickshell (qs) is required")
    if args.command == "preview":
        env = os.environ.copy()
        env.update(HELLO_POLKIT_PREVIEW="1", HELLO_POLKIT_PREVIEW_STATE=args.state,
                   HELLO_POLKIT_PREVIEW_SUCCESS="0" if args.failure else "1", HELLO_POLKIT_CAPTURE_DIR="")
        if args.capture:
            captures = ROOT / ".cache/previews"
            captures.mkdir(parents=True, exist_ok=True)
            env["HELLO_POLKIT_CAPTURE_DIR"] = str(captures)
        raise SystemExit(subprocess.call([qs, "--no-duplicate", "--path", str(ROOT / "shell.qml")], env=env))
    elif args.command == "install":
        backup = install(ROOT, paths, qs, find_mate(args.mate))
        print(f"Installed files. Backup: {backup}\nRun make activate when ready to switch agents.")
    elif args.command == "activate":
        activate(qs, paths)
    else:
        print(json.dumps(status(qs, paths), indent=2))


if __name__ == "__main__":
    main()
