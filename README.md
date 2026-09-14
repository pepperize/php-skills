# php-skills

Reusable PHP agent skills for applying company engineering standards across PHP codebases.

## Skills

- `php-readable-code`: readable PHP code, focused responsibilities, factory naming, nullable collection handling, and avoiding hard-to-read nested method calls.
- `php-templating`: typed presentation models, template engine selection, layouts and partials, HTML escaping, interface translation, and complete source-controlled localized page and email content.
- `php-testing-style`: PHPUnit unit and integration testing conventions, London-style defaults, test layout, naming, and verification scope.
- `php-solid-review`: SOLID, responsibility-boundary, code-smell, and pragmatic OO design review for PHP production code. Testing guidance stays delegated to `php-testing-style`.
- `php-agent-instructions`: installs or updates project-level `AGENTS.md`/`CLAUDE.md` instructions for PHP skill self-review.
- `php-logging-exceptions`: logging and exception placement guidance for domain-relevant failures and technical boundaries.
- `php-application-security`: application security guidance for external-input validation and regex safety.
- `php-rbac-authorization`: RBAC authorization guidance for method-local permission attributes, centralized role-to-permission mappings, capability checks, and object-scoped access rules.
- `php-domain-clarification`: clarification workflow before domain-sensitive implementation changes.
- `php-shared-hosting-deployment`: GitHub Actions deployment guidance for PHP applications on SSH-accessible shared hosting, including exact artifact promotion, immutable releases, private persistent state, smoke gates, rollback, and fail-closed retention.
- `php-clean-architecture`: Clean Architecture guidance for PHP projects. This skill is guarded and should only be used when the project's main instruction file explicitly states Clean Architecture.
- `php-ddd-architecture`: DDD guidance for PHP projects, including repository ownership and contracts, framework configuration placement, web boundary naming, form-validation middleware, and Slim route URL generation. This skill is guarded and should only be used when the project's main instruction file explicitly states DDD or Domain-Driven Design.
- `php-database-migrations`: migration creation, framework selection, timestamp naming, and applied-migration integrity conventions for PHP projects.

## Architecture Skill Activation

Architecture skills are intentionally conditional. They should not be activated just because a task mentions architecture, refactoring, or design.

Use `php-clean-architecture` only when `AGENTS.md`, `CLAUDE.md`, or the project's equivalent main instruction file explicitly states that the project uses Clean Architecture.

Use `php-ddd-architecture` only when the main instruction file explicitly states that the project uses DDD or Domain-Driven Design.

## Local Installation

Install or refresh links into the local agent skills directory.

Linux:

```bash
./scripts/install-local-skills.sh
```

macOS:

```bash
./scripts/install-local-skills-macos.sh
```

Windows PowerShell:

```powershell
.\scripts\install-local-skills-windows.ps1
```

Set `AGENTS_SKILLS_DIR` to install somewhere other than `$HOME/.agents/skills`.

## License

This project is licensed under the Apache License 2.0. You may use, copy, modify, distribute, and adapt this skill collection, including for commercial purposes, subject to the terms of the license.

Attribution is appreciated via a link back to the original repository: https://github.com/pepperize/php-skills.

The skill collection is provided "as is", without warranties or conditions of any kind. As summarized from the Apache License 2.0 disclaimer and limitation of liability, except where required by applicable law or agreed in writing, Pepperize UG is not responsible for harm, damages, or losses arising from use of the skill collection.
