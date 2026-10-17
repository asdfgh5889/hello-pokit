"""Fetch the optional animation build input; never needed at runtime."""
from pathlib import Path
import hashlib
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
URL = "https://www.windowslatest.com/wp-content/uploads/2024/11/Windows-Hello-new-animation.gif"
SHA256 = "6cec6e88034c225609c2345bf3092beda5cbb83a6d9f8ce5f9bfc1d11638acff"


def main():
    path = ROOT / ".cache/reference/windows-hello.gif"
    if path.exists() and hashlib.sha256(path.read_bytes()).hexdigest() == SHA256:
        print(path)
        return
    request = urllib.request.Request(URL, headers={"User-Agent": "hello-polkit-reference-builder/0.1"})
    with urllib.request.urlopen(request, timeout=45) as response:
        data = response.read(20_000_001)
    if len(data) > 20_000_000 or hashlib.sha256(data).hexdigest() != SHA256:
        raise SystemExit("Reference changed: SHA-256 mismatch; no output written")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    print(path)


if __name__ == "__main__":
    main()
