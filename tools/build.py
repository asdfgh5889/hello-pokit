"""Create a portable source/runtime bundle without network access."""
from pathlib import Path
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]
DIRECTORIES = ("qml", "assets", "licenses", "templates", "tools", "tests", "docs")
FILES = ("shell.qml", "README.md", "REFERENCES.md", "NOTICE.md", "Makefile", "pyproject.toml", "uv.lock", ".gitignore", ".python-version")


def build(root=ROOT, output=None):
    output = output or root / "dist/hello-polkit"
    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True)
    for name in DIRECTORIES:
        shutil.copytree(root / name, output / name,
                        ignore=shutil.ignore_patterns("__pycache__", "*.pyc", "palette.json"))
    for name in FILES:
        shutil.copy2(root / name, output / name)
    hashes = {str(path.relative_to(output)): hashlib.sha256(path.read_bytes()).hexdigest()
              for path in sorted(output.rglob("*")) if path.is_file()}
    (output / "MANIFEST.sha256.json").write_text(json.dumps(hashes, indent=2) + "\n")
    return output


if __name__ == "__main__":
    print(build())
