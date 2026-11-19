#!/usr/bin/env python3
"""Finishes a `flutter build web` output for offline use.

- Stamps web/sw.js with a build id (a hash of precache_manifest.json), so every
  release installs a fresh offline cache and removes the previous one.
- Removes files that are not needed at runtime (source maps).

Usage: python3 tool/web/finalize_build.py build/web
"""
import hashlib
import pathlib
import sys


def main() -> int:
    out = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "build/web")
    manifest = out / "precache_manifest.json"
    sw = out / "sw.js"
    if not manifest.exists() or not sw.exists():
        print("error: build with --web-content-hash and keep web/sw.js", file=sys.stderr)
        return 1

    build_id = hashlib.sha256(manifest.read_bytes()).hexdigest()[:12]
    text = sw.read_text(encoding="utf-8")
    if "__BUILD_ID__" not in text:
        print("sw.js already finalized")
    else:
        sw.write_text(text.replace("__BUILD_ID__", build_id), encoding="utf-8")
        print(f"sw.js build id: {build_id}")

    for source_map in out.rglob("*.map"):
        source_map.unlink()
    return 0


if __name__ == "__main__":
    sys.exit(main())
