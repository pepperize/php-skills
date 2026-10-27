# php-skills

Reusable PHP agent skills for applying company engineering standards across PHP codebases.

## Skills

- [php-api-endpoints](php-api-endpoints/SKILL.md): REST resource responsibilities, DTO/entity flow, persistence mapping, endpoint contracts, and HTTP success responses. Read the [worked User endpoint](php-api-endpoints/references/user-endpoint.md) before implementing an API endpoint.
- [php-readable-code](php-readable-code/SKILL.md): class, factory, dependency, repository and REST naming; orchestration, guards, collections, and readability. See [HTTP endpoint examples](php-readable-code/references/http-endpoint-examples.md).
- `php-templating`: typed presentation models, template engine selection, layouts and partials, HTML escaping, interface translation, and complete source-controlled localized page and email content.
- `php-testing-style`: PHPUnit unit and integration testing conventions, London-style defaults, test layout, naming, and verification scope.
- `php-solid-review`: pragmatic code, architecture, design, and implementation self-review using SOLID, DRY, KISS, composition, encapsulation, collaboration, and simplicity principles. Findings name only principles that materially apply. Testing guidance stays delegated to `php-testing-style`.
- `php-agent-instructions`: installs or updates project-level `AGENTS.md`/`CLAUDE.md` instructions for PHP skill self-review.
- `php-logging-exceptions`: logging and exception placement guidance for domain-relevant failures and technical boundaries.
- `php-application-security`: application security guidance for external-input validation and regex safety.
- [php-request-validation](php-request-validation/SKILL.md): input validation with unchanged submitted values, DTO sharing and delivery, Problem Details, browser submissions, and regex sharing.
- `php-authentication-security`: secure password authentication, login throttling, recovery and verification tokens, session lifecycle, and Mezzio authentication integration.
- `php-rbac-authorization`: RBAC authorization guidance for method-local permission attributes, centralized role-to-permission mappings, capability checks, and object-scoped access rules.
- `php-domain-clarification`: clarification workflow before domain-sensitive implementation changes.
- [php-shared-hosting-deployment](php-shared-hosting-deployment/SKILL.md): guarded shared-hosting deployment guidance with copyable SQLite and MariaDB examples, verified copying, exact artifact promotion, private state, recovery, rollback and tested retention.
- `php-clean-architecture`: Clean Architecture guidance for PHP projects. This skill is guarded and should only be used when the project's main instruction file explicitly states Clean Architecture.
- `php-ddd-architecture`: DDD guidance for PHP projects, including repository ownership and contracts, framework configuration placement, web boundary naming, form-validation middleware, and Slim route URL generation. This skill is guarded and should only be used when the project's main instruction file explicitly states DDD or Domain-Driven Design.
- `php-database-migrations`: migration creation, framework selection, timestamp naming, and applied-migration integrity conventions for PHP projects.

## Rule Ownership

Each complete rule has one owner below. Other skills and project instructions retain short decision/reminder checks and link to that owner. Worked examples illustrate the contracts; they do not define competing defaults. Change the owning rule when policy changes, then update affected reminders and examples.

| Rule | Authoritative owner |
| --- | --- |
| Naming, factories, dependency names, repository methods, readability | [PHP Readable Code](php-readable-code/SKILL.md) |
| Resource flow, endpoint classification, REST success responses, Doctrine mapping policy | [PHP API Endpoints](php-api-endpoints/SKILL.md) |
| Input validation, DTO sharing/hydration, regex sharing, browser forms and HTML submissions | [PHP Request Validation](php-request-validation/SKILL.md) |
| Slim DTO binding and wiring failures | [Controller argument reference](php-request-validation/references/slim-controller-arguments.md) |
| Problem Details envelope, statuses and error locations | [Problem Details reference](php-request-validation/references/problem-details.md) |
| Regex execution safety and contextual output handling | [PHP Application Security](php-application-security/SKILL.md) |
| Page ViewModels, rendering, HTML escaping and localized content | [PHP Templating](php-templating/SKILL.md) |
| Test conventions, boundary coverage and verification scope | [PHP Testing Style](php-testing-style/SKILL.md) |
| Design findings and implementation self-review | [PHP Design Review](php-solid-review/SKILL.md) |
| Instruction installation and the project self-review checklist | [PHP Agent Instructions](php-agent-instructions/SKILL.md) and its [single template](php-agent-instructions/assets/php-skill-self-review.md) |
| Logging and exception boundaries | [PHP Logging And Exceptions](php-logging-exceptions/SKILL.md) |
| Passwords, authentication, recovery and session lifecycle | [PHP Authentication Security](php-authentication-security/SKILL.md) |
| Permissions, protected routes and object-scoped authorization | [PHP RBAC Authorization](php-rbac-authorization/SKILL.md) |
| Domain clarification | [PHP Domain Clarification](php-domain-clarification/SKILL.md) |
| DDD ownership/layout and Slim route generation; Clean Architecture boundaries | [PHP DDD Architecture](php-ddd-architecture/SKILL.md); [PHP Clean Architecture](php-clean-architecture/SKILL.md), each subject to its own guard |
| Migrations; shared-host deployment and its activation guard | [PHP Database Migrations](php-database-migrations/SKILL.md); [PHP Shared Hosting Deployment](php-shared-hosting-deployment/SKILL.md) |

## Architecture Skill Activation

Architecture skills are intentionally conditional. They should not be activated just because a task mentions architecture, refactoring, or design.

Use `php-clean-architecture` only when `AGENTS.md`, `CLAUDE.md`, or the project's equivalent main instruction file explicitly states that the project uses Clean Architecture.

Use `php-ddd-architecture` only when the main instruction file explicitly states that the project uses DDD or Domain-Driven Design.

## Shared Hosting Skill Activation

Use `php-agent-instructions` to record whether the project uses SSH-accessible shared hosting and whether its database is SQLite or MariaDB. The deployment skill activates only when root `AGENTS.md` contains the standalone shared-hosting marker and exactly one supported database marker:

```markdown
<!-- php-skills:hosting:shared -->
<!-- php-skills:database:sqlite -->
```

Use `<!-- php-skills:database:mariadb -->` instead for MariaDB. Missing or conflicting markers keep deployment guidance inactive. A confirmed profile can be installed from the target project root with:

```bash
python3 /path/to/php-agent-instructions/scripts/install-agent-instructions.py \
  --hosting shared --database sqlite
```

These markers select guidance and the matching example; they do not authorize live deployment.

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
