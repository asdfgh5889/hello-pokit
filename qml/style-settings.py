#!/usr/bin/python3
"""Stream resolved Noctalia typography and radii after configuration changes."""
import ctypes
import json
import math
import os
from pathlib import Path
import select
import shutil
import subprocess
import sys
import tomllib


def directories():
    home = Path.home()
    config_base = os.environ.get("NOCTALIA_CONFIG_HOME") or os.environ.get("XDG_CONFIG_HOME") or home / ".config"
    state_base = os.environ.get("NOCTALIA_STATE_HOME") or os.environ.get("XDG_STATE_HOME") or home / ".local/state"
    return Path(config_base) / "noctalia", Path(state_base) / "noctalia"


def resolved_style():
    binary = shutil.which("noctalia")
    if binary is None:
        return {"fontFamily": "sans-serif", "cornerRadiusScale": 1.0}
    result = subprocess.run([binary, "config", "export", "full"],
                            capture_output=True, text=True, check=True, timeout=5)
    shell = tomllib.loads(result.stdout).get("shell", {})
    family = shell.get("font_family", "sans-serif")
    scale = shell.get("corner_radius_scale", 1.0)
    if not isinstance(family, str) or not family.strip():
        family = "sans-serif"
    if isinstance(scale, bool) or not isinstance(scale, (int, float)) or not math.isfinite(scale):
        raise ValueError("Invalid corner-radius scale")
    return {"fontFamily": family.strip(), "cornerRadiusScale": max(0.0, min(2.0, scale))}


def fingerprint(config, state):
    paths = sorted(config.glob("*.toml")) + [state / "settings.toml"]
    values = []
    for path in paths:
        try:
            stat = path.stat()
            values.append((str(path), stat.st_ino, stat.st_size, stat.st_mtime_ns))
        except FileNotFoundError:
            values.append((str(path), None))
    return tuple(values)


def main():
    if "--once" in sys.argv:
        print(json.dumps(resolved_style()), flush=True)
        return
    config, state = directories()
    libc = ctypes.CDLL(None, use_errno=True)
    libc.inotify_init1.argtypes = [ctypes.c_int]
    libc.inotify_init1.restype = ctypes.c_int
    libc.inotify_add_watch.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_uint32]
    libc.inotify_add_watch.restype = ctypes.c_int
    fd = libc.inotify_init1(os.O_NONBLOCK | os.O_CLOEXEC)
    if fd < 0:
        raise OSError(ctypes.get_errno(), "Cannot watch Noctalia settings")
    # Directory watches survive atomic file replacement. Ancestors cover recreation.
    watched = set()
    previous = None
    stamp = None
    try:
        while True:
            for target in (config, state):
                for directory in (target, *target.parents):
                    if directory in watched or not directory.is_dir():
                        continue
                    mask = 0x00000008 | 0x00000080 | 0x00000100 | 0x00000200 | 0x00000400 | 0x00000800
                    if libc.inotify_add_watch(fd, os.fsencode(directory), mask) >= 0:
                        watched.add(directory)
                    if directory != target:
                        break
            current = fingerprint(config, state)
            if current != stamp:
                stamp = current
                try:
                    value = resolved_style()
                    if value != previous:
                        print(json.dumps(value), flush=True)
                        previous = value
                except (subprocess.SubprocessError, ValueError, OSError):
                    print("Keeping the last valid Noctalia font and radius settings", file=sys.stderr, flush=True)
            select.select([fd], [], [])
            os.read(fd, 65536)
            # Coalesce editor saves and settings updates without periodic polling.
            while select.select([fd], [], [], 0.1)[0]:
                os.read(fd, 65536)
            # Re-add directory watches if a watched directory was replaced.
            watched.clear()
    finally:
        os.close(fd)


if __name__ == "__main__":
    main()
