#!/usr/bin/env python3
"""Build and package a local single-threaded browser trial. Python stdlib only."""
import argparse
from pathlib import Path
import shutil
import subprocess
import zipfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    output = root / "build" / "web"
    output.mkdir(parents=True, exist_ok=True)
    subprocess.run([args.godot, "--headless", "--path", str(root),
                    "--export-release", "Web Trial", str(output / "index.html")], check=True)
    for name in ["serve.py", "play-linux.sh", "play-windows.bat", "PLAY_WEB.txt"]:
        shutil.copy2(Path(__file__).parent / name, output / name)
    (output / "play-linux.sh").chmod(0o755)
    destination = root / "dist" / "ProjectMine-web-trial.zip"
    destination.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for item in sorted(output.iterdir()):
            if item.is_file():
                archive.write(item, item.name)
    print(f"Web folder: {output}\nPortable trial: {destination}")
    print("Start: python3 tools/web/serve.py")


if __name__ == "__main__":
    main()
