"""Explicit Arch/CachyOS Polkit-only switch to Gaze simultaneous mode (pkexec)."""
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import shutil
import tempfile
import tomllib

def main():
    if os.geteuid() != 0:
        raise SystemExit("Run explicitly through pkexec /usr/bin/python3 tools/configure-polkit-pam.py")
    config = tomllib.loads(Path("/etc/gaze/config.toml").read_text())
    if config.get("auth", {}).get("require_confirmation_elevation") is not True:
        raise SystemExit("Enable elevation confirmation before changing this Polkit stack")
    path = Path("/etc/pam.d/polkit-1")
    info = path.stat()
    if path.is_symlink() or info.st_uid != 0 or info.st_mode & 0o022:
        raise SystemExit("Unexpected PAM file ownership or permissions")
    text = path.read_text()
    pattern = r"(?m)^(auth\s+sufficient\s+pam_gaze\.so)(?:\s+(simultaneous))?[ \t]*$"
    matches = list(re.finditer(pattern,text))
    if len(matches) != 1:
        raise SystemExit("Expected exactly one supported Gaze auth line; no change made")
    if matches[0][2] == "simultaneous":
        print("Polkit already uses simultaneous mode");return
    replacement = re.sub(pattern,r"\1 simultaneous",text)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
    backup = Path("/var/lib/hello-polkit/pam-backups")/stamp
    backup.mkdir(parents=True,mode=0o700)
    shutil.copy2(path,backup/"polkit-1")
    descriptor, temporary = tempfile.mkstemp(prefix=".hello-polkit-",dir=path.parent)
    try:
        with os.fdopen(descriptor,"w") as stream:
            stream.write(replacement);stream.flush();os.fsync(stream.fileno())
        os.chmod(temporary,info.st_mode & 0o777);os.chown(temporary,info.st_uid,info.st_gid)
        os.replace(temporary,path)
    finally:
        if os.path.exists(temporary):os.unlink(temporary)
    print(json.dumps({"changed":str(path),"mode":"simultaneous","backup":str(backup/"polkit-1")}))

if __name__ == "__main__":main()
