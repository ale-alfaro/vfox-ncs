#!/usr/bin/env -S uv run --script
#
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "pyelftools",
#     "PyYAML",
#     "pykwalify",
#     "jsonschema",
#     "canopen",
#     "packaging",
#     "patool",
#     "psutil",
#     "pylink-square",
#     "pyserial",
#     "requests",
#     "semver",
#     "tqdm",
#     "reuse",
#     "anytree",
#     "intelhex",
#     "west",
# ]
# ///

import os
import subprocess  # noqa: S404
import sys
from pathlib import Path

from west.configuration import Configuration
from west.util import WestNotFound, west_topdir


def run_west_cmd(
    west_cmd: list[str],
    topdir: Path | None = None,
) -> None:
    cmd = ["uvx"]

    if topdir and topdir.is_dir():
        # NCS workspaces have requirements in both nrf/ and zephyr/
        for subdir in ("nrf", "zephyr"):
            req = topdir / subdir / "scripts" / "requirements-base.txt"
            if req.is_file():
                cmd.extend(["--with-requirements", str(req)])

    cmd.extend(["west", *west_cmd])

    # Defense-in-depth: clear Python env vars that may leak from toolchain activation
    for var in ("VIRTUAL_ENV", "PYTHONPATH", "PYTHONHOME"):
        os.environ.pop(var, None)

    try:
        subprocess.run(
            cmd,
            check=True,
        )
    except subprocess.CalledProcessError as exc:
        print(f"west failed with return code {exc.returncode}")
        sys.exit(exc.returncode)


def main():
    west_args = sys.argv[1:]
    topdir_path = None
    try:
        if topdir := west_topdir(None, fall_back=True):
            topdir_path = Path(topdir)
    except WestNotFound:
        print("No west workspace found, are you inside a workspace?")

    run_west_cmd(west_args, topdir_path)


if __name__ == "__main__":
    main()
