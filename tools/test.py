"""Run isolated packaging/theme tests and offscreen QML authentication/motion checks."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    subprocess.run([sys.executable, "-m", "unittest", "discover", "-s", "tests", "-v"], cwd=ROOT, check=True)
    runner = os.environ.get("QMLTESTRUNNER") or shutil.which("qmltestrunner6") or shutil.which("qmltestrunner")
    if not runner:
        runner = next((str(p) for p in (Path("/usr/lib/qt6/bin/qmltestrunner"),
                                       Path("/usr/lib64/qt6/bin/qmltestrunner")) if p.is_file()), None)
    if not runner:
        raise SystemExit("Qt 6 qmltestrunner is required; set QMLTESTRUNNER to its path")
    (ROOT / ".cache/test-artifacts").mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env.update(QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software")
    subprocess.run([runner, "-input", str(ROOT / "tests/qml")], cwd=ROOT, env=env, check=True)
    quickshell = shutil.which("qs") or shutil.which("quickshell")
    if not quickshell:
        raise SystemExit("Stock Quickshell is required for the monotonic expiry integration check")
    # Quickshell's scanner confines imports to the entry point's directory tree.
    with tempfile.NamedTemporaryFile("w", prefix=".expiry-test-", suffix=".qml", dir=ROOT) as entry:
        entry.write('import "tests/quickshell"\nExpirationTest {}\n')
        entry.flush()
        subprocess.run([quickshell, "--path", entry.name], cwd=ROOT, env=env, check=True, timeout=25)


if __name__ == "__main__":
    main()
