#!/usr/bin/env python3
"""Copy a verified deployment example without overwriting project files."""

import argparse
import hashlib
import json
import os
import re
from pathlib import Path, PurePosixPath
import sys


EXAMPLES = {"sqlite": "sqlite-example", "mariadb": "mariadb-example"}


def load_example(database):
    root = Path(__file__).resolve().parents[1] / "assets" / EXAMPLES[database]
    snapshot = json.loads((root / "manifest.json").read_text())
    if snapshot["database"] != database:
        raise ValueError("Example database does not match the selected profile.")

    contents = {}
    for relative, expected_hash in snapshot["files"].items():
        path = PurePosixPath(relative)
        if path.is_absolute() or ".." in path.parts or path.as_posix() != relative:
            raise ValueError(f"Unsafe example path: {relative}")
        source = root / relative
        if source.is_symlink() or not source.resolve().is_relative_to(root.resolve()):
            raise ValueError(f"Template file escapes its example: {relative}")
        payload = source.read_bytes()
        if hashlib.sha256(payload).hexdigest() != expected_hash:
            raise ValueError(f"Template hash mismatch: {relative}")
        contents[relative] = (payload, source.stat().st_mode & 0o777)

    return snapshot, {relative: contents[relative] for relative in snapshot["copy_files"]}


def render_site(files, site):
    if len(site) > 253 or "." not in site or not all(
        re.fullmatch(r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?", label)
        for label in site.split(".")
    ):
        raise ValueError("Site must be a lowercase DNS hostname, without a scheme or path.")
    return {
        name: (
            payload.replace(b"example\\.com", site.replace(".", "\\.").encode())
            .replace(b"example.com", site.encode()),
            mode,
        )
        for name, (payload, mode) in files.items()
    }


def check_destinations(target, files):
    if target.exists() and not target.is_dir():
        raise ValueError(f"Project root is not a directory: {target}")
    for relative in files:
        destination = target / relative
        if destination.exists() or destination.is_symlink():
            raise FileExistsError(f"Refusing to overwrite existing file: {destination}")
        for parent in destination.parents:
            if parent == target:
                break
            if parent.is_symlink() or (parent.exists() and not parent.is_dir()):
                raise ValueError(f"Destination parent is a symlink or file: {parent}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database", choices=EXAMPLES, required=True)
    parser.add_argument("--site", default="example.com", help="Site hostname; defaults to example.com")
    parser.add_argument("--target", type=Path, required=True, help="Target project directory")
    parser.add_argument("--dry-run", action="store_true", help="List files without writing")
    arguments = parser.parse_args()

    try:
        snapshot, files = load_example(arguments.database)
        files = render_site(files, arguments.site)
        target = arguments.target.resolve()
        check_destinations(target, files)
        if arguments.dry_run:
            print(f"Would copy {len(files)} files from {snapshot['template']} for {arguments.site} into {target}:")
            print("\n".join(files))
            return 0

        for relative, (payload, mode) in files.items():
            destination = target / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            with destination.open("xb") as stream:
                stream.write(payload)
            os.chmod(destination, mode)

        print(f"Copied {len(files)} files from {snapshot['template']} for {arguments.site} into {target}.")
        print("Adapt site settings, build/preparation commands and smoke checks using references/copy-examples.md before enabling workflows.")
        return 0
    except (OSError, ValueError, KeyError) as error:
        print(f"Pipeline copy failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
