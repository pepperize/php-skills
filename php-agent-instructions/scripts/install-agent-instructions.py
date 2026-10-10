#!/usr/bin/env python3
"""Install or update PHP skill self-review instructions."""

from __future__ import annotations

import argparse
from pathlib import Path

START = "<!-- php-skills:self-review:start -->"
END = "<!-- php-skills:self-review:end -->"
PROFILE_START = "<!-- php-skills:deployment-profile:start -->"
PROFILE_END = "<!-- php-skills:deployment-profile:end -->"
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
    parser.add_argument("--hosting", choices=("shared", "other"), help="Confirmed deployment target.")
    parser.add_argument("--database", choices=("sqlite", "mariadb"), help="Confirmed shared-hosting database.")
    args = parser.parse_args()
    if args.hosting == "shared" and args.database is None:
        parser.error("--hosting shared requires --database sqlite or mariadb")
    if args.database is not None and args.hosting != "shared":
        parser.error("--database requires --hosting shared")
    return args


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


def replace_block(existing: str, start: str, end: str, block: str) -> str:
    if existing.count(start) != existing.count(end) or existing.count(start) > 1:
        raise ValueError("Incomplete or duplicate php-skills block markers; refusing to update.")
    if start in existing:
        before, rest = existing.split(start, 1)
        if end not in rest:
            raise ValueError("Reversed php-skills block markers; refusing to update.")
        _, after = rest.split(end, 1)
        prefix = before.rstrip()
        if prefix:
            prefix += "\n\n"
        suffix = after.lstrip()
        replacement = block.rstrip() + "\n\n" if block and suffix else block
        return prefix + replacement + suffix
    if not block:
        return existing
    if not existing.strip():
        return block
    return existing.rstrip() + "\n\n" + block


def update_content(existing: str) -> str:
    return replace_block(existing, START, END, BLOCK)


def update_profile(existing: str, hosting: str, database: str | None) -> str:
    block = ""
    if hosting == "shared":
        block = (
            f"{PROFILE_START}\n"
            "## Deployment Profile\n\n"
            "<!-- php-skills:hosting:shared -->\n"
            f"<!-- php-skills:database:{database} -->\n\n"
            f"This project uses SSH-accessible shared hosting with {database}. "
            "Use `php-shared-hosting-deployment` and its matching database example "
            "for deployment work.\n"
            f"{PROFILE_END}\n"
        )
    return replace_block(existing, PROFILE_START, PROFILE_END, block)


def main() -> None:
    args = parse_args()
    target = resolve_target(args.file)

    existing = target.read_text(encoding="utf-8") if target.exists() else ""
    updated = update_content(existing)

    updates = {target: (existing, updated)}
    if args.hosting is not None:
        agents = Path("AGENTS.md")
        if agents.resolve() == target.resolve():
            updates[target] = (existing, update_profile(updated, args.hosting, args.database))
        else:
            agents_existing = agents.read_text(encoding="utf-8") if agents.exists() else ""
            agents_updated = update_profile(agents_existing, args.hosting, args.database)
            if agents_updated != agents_existing:
                updates[agents] = (agents_existing, agents_updated)

    # Resolve and validate both files before writing either one.
    for path, (previous, content) in updates.items():
        path.write_text(content, encoding="utf-8")
        action = "Updated" if previous else "Created"
        print(f"{action}: {path}")


if __name__ == "__main__":
    main()
