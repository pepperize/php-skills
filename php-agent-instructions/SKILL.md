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
2. Add or update the marked `PHP Skill Self Review` block.
3. Keep existing unrelated instructions intact.
4. Do not infer that a project uses Clean Architecture or DDD; only project instructions can state that.
5. Review the diff for the target file before finalizing.

Prefer the bundled script for idempotent installs. Run it from the target repo root, resolving the script path relative to this skill directory:

```bash
python3 /path/to/php-agent-instructions/scripts/install-agent-instructions.py
```

Pass `--file CLAUDE.md` or another path when the user requests a specific target.

## Instruction Block

```md
<!-- php-skills:self-review:start -->
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
```
