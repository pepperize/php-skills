#!/usr/bin/env python3
"""Install or update PHP skill self-review instructions."""

from __future__ import annotations

import argparse
from pathlib import Path

START = "<!-- php-skills:self-review:start -->"
END = "<!-- php-skills:self-review:end -->"

BLOCK = """<!-- php-skills:self-review:start -->
## PHP Skill Self Review

After making PHP code, test, or skill changes, review the diff before the final response.

- Treat relevant PHP skills as executable checklists, not background reading.
- Before editing, name the applicable skills and the exact rules that constrain naming, exceptions, logging, validation, testing, migrations, and architecture.
- Use `php-domain-clarification` before coding when domain rules, identifiers, persistence shape, scoping, or externally visible behavior are unclear.
- Use `php-solid-review` for design, responsibility, SOLID, code-smell, and refactoring concerns.
- Use `php-readable-code` for naming, guard clauses, factories, utilities, and readability.
- Use `php-templating` for server-rendered controllers, page templates, partials, and template-input changes.
- Use `php-testing-style` for all test naming, mocks, unit/integration boundaries, assertions, layout, and verification scope.
- Use `php-application-security` for input validation, regex safety, and other application-security-sensitive code paths.
- Use `php-logging-exceptions` and `php-database-migrations` when changes touch those areas.
- Use `php-clean-architecture` and `php-ddd-architecture` only when this project's instructions explicitly state those architectures.
- Before finalizing, review new or changed helper methods with `php-readable-code`.
- Before finalizing, review thrown/caught exceptions and logging decisions with `php-logging-exceptions`.
- Before finalizing a server-rendered page, verify that it receives one typed page ViewModel, structured nested values use ViewModels, and render arrays exist only as template-engine adapters.
- Do not add defensive branches unless the domain/API path can actually produce that state.
- Fix issues found during self-review before finalizing.
- Keep cleanup scoped to the requested change.
<!-- php-skills:self-review:end -->
"""


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
        return before.rstrip() + "\n\n" + BLOCK + after.lstrip()

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
