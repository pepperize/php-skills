#!/usr/bin/env python3
"""Install or update PHP skill self-review instructions."""

from __future__ import annotations

import argparse
from pathlib import Path

START = "<!-- php-skills:self-review:start -->"
END = "<!-- php-skills:self-review:end -->"
BLOCK_PATH = (
    Path(__file__).resolve().parent.parent
    / "assets"
    / "php-skill-self-review.md"
)
BLOCK = BLOCK_PATH.read_text(encoding="utf-8")
if not BLOCK.endswith("\n"):
    BLOCK += "\n"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Install PHP skill self-review instructions into AGENTS.md or CLAUDE.md."
    )
    parser.add_argument(
        "--file",
        help="Instruction file to update. Defaults to AGENTS.md, existing CLAUDE.md, or new AGENTS.md.",
    )
    return parser.parse_args()


def resolve_target(requested_file: str | None) -> Path:
    if requested_file:
        return Path(requested_file)

    agents = Path("AGENTS.md")
    claude = Path("CLAUDE.md")

    if agents.exists():
        return agents

    if claude.exists():
        return claude

    return agents


def update_content(existing: str) -> str:
    has_start = START in existing
    has_end = END in existing

    if has_start != has_end:
        raise ValueError("Found only one php-skills self-review marker; refusing to update.")

    if has_start:
        before, rest = existing.split(START, 1)
        _, after = rest.split(END, 1)
        prefix = before.rstrip()
        if prefix:
            prefix += "\n\n"

        return prefix + BLOCK + after.lstrip()

    if not existing.strip():
        return BLOCK

    return existing.rstrip() + "\n\n" + BLOCK


def main() -> None:
    args = parse_args()
    target = resolve_target(args.file)

    existing = target.read_text(encoding="utf-8") if target.exists() else ""
    updated = update_content(existing)

    target.write_text(updated, encoding="utf-8")
    action = "Updated" if existing else "Created"
    print(f"{action}: {target}")


if __name__ == "__main__":
    main()
