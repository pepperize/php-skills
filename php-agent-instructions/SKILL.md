---
name: php-agent-instructions
description: Installs or updates project-level agent instructions for PHP projects that use these PHP skills. Use when adding suggested PHP skill self-review instructions to AGENTS.md, CLAUDE.md, or an equivalent agent instruction file.
---

# PHP Agent Instructions

## Scope

Use this skill to install a small project-level instruction block that tells agents to self-review PHP changes with the relevant PHP skills.

Preserve existing project instructions. Do not replace an entire `AGENTS.md`, `CLAUDE.md`, or equivalent file.

## Target File

- If the user names a target file, use that file.
- Otherwise update root `AGENTS.md` when it exists.
- If `AGENTS.md` is absent but root `CLAUDE.md` exists, update `CLAUDE.md`.
- If neither exists, create root `AGENTS.md`.
- If both exist and the user did not choose, update `AGENTS.md` and leave `CLAUDE.md` unchanged.

## Install Workflow

1. Inspect the target instruction file before changing it.
2. Read root `AGENTS.md` for an existing confirmed deployment profile. If the user has not already supplied the answers and no profile is recorded, ask: "Is this project deployed to SSH-accessible shared hosting?" If yes, ask: "Does it use SQLite or MariaDB?" Ask these together when convenient. Do not infer the answers from dependencies, directory names or workflow files.
3. Add or update the marked `PHP Skill Self Review` block. Record a confirmed shared-hosting answer and supported database in the separate deployment-profile block in root `AGENTS.md`, even when the self-review target is `CLAUDE.md` or another file.
4. Keep existing unrelated instructions and an existing confirmed profile intact. If the user confirms another hosting target, remove the managed deployment-profile block. If answers are pending or the database is unsupported, install the self-review block without adding activation markers.
5. Do not infer that a project uses Clean Architecture or DDD; only project instructions can state that.
6. Review the diff for every updated instruction file before finalizing.

Prefer the bundled script for idempotent installs. Run it from the target repo root, resolving the script path relative to this skill directory:

```bash
python3 /path/to/php-agent-instructions/scripts/install-agent-instructions.py
```

Pass `--file CLAUDE.md` or another path when the user requests a specific target.

For a confirmed shared-hosting project, pass the answers explicitly:

```bash
python3 /path/to/php-agent-instructions/scripts/install-agent-instructions.py \
  --hosting shared --database sqlite
```

Use `--database mariadb` for MariaDB, or `--hosting other` to remove a previously managed shared-hosting profile. Without these flags the installer preserves existing deployment markers and does not prompt or invent answers.

The activation markers are standalone comments in root `AGENTS.md`:

```markdown
<!-- php-skills:hosting:shared -->
<!-- php-skills:database:sqlite -->
```

For MariaDB, use `<!-- php-skills:database:mariadb -->` instead of the SQLite marker. Exactly one supported database profile must be selected. These markers activate the deployment skill only for deployment work; they do not authorize a live release.

## Instruction Block

Before installing or reproducing the block, read
[php-skill-self-review.md](assets/php-skill-self-review.md). It is the
authoritative template used by the bundled installer; do not maintain another
copy in this file or the script.
