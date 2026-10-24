#!/usr/bin/env python3
"""Package source, documentation, tests and licensed assets without local state."""
from pathlib import Path
import hashlib
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "builds" / "WarSerpentIO-Source.zip"
EXCLUDED_DIRS = {".git", ".godot", "builds", "__pycache__", ".cache", ".config", ".local"}
EXCLUDED_SUFFIXES = {".keystore", ".jks", ".apk", ".idsig", ".pyc", ".tmp", ".bak", ".log"}

def main():
    OUT.parent.mkdir(exist_ok=True)
    included = []
    with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(ROOT.rglob("*")):
            relative = path.relative_to(ROOT)
            if any(part in EXCLUDED_DIRS for part in relative.parts):
                continue
            if not path.is_file() or path.suffix.lower() in EXCLUDED_SUFFIXES:
                continue
            if path.is_symlink():
                raise RuntimeError(f"Refusing symlink in source package: {relative}")
            archive.write(path, Path("WarSerpentIO") / relative)
            included.append(str(relative))
    with zipfile.ZipFile(OUT) as archive:
        assert archive.testzip() is None, "Source ZIP CRC failure"
        names = set(archive.namelist())
        for required in ["project.godot", "scenes/Main.tscn", "scripts/ui/Main.gd",
                         "scripts/gameplay/ArenaGame.gd", "assets/backgrounds/menu.png",
                         "data/catalog.json", "README.md", "LICENSE", "BUILD_REPORT.md",
                         "export_presets.cfg", "tests/test_flow.gd", "tools/build_android.sh"]:
            assert "WarSerpentIO/" + required in names, required
        assert not any(".keystore" in name or "/.godot/" in name for name in names)
    print(f"Source ZIP verified: {len(included)} files, {OUT.stat().st_size} bytes")
    print(f"SHA256 {hashlib.sha256(OUT.read_bytes()).hexdigest()}  {OUT.name}")

if __name__ == "__main__":
    main()
