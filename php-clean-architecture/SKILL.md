---
name: php-clean-architecture
description: Applies Clean Architecture guidance for PHP projects. Use only when the project's main instruction file such as AGENTS.md, CLAUDE.md, or equivalent explicitly states that the project uses Clean Architecture, especially when adding use cases, ports, adapters, factories, or refactoring boundaries.
---

# PHP Clean Architecture

## Activation Guard

Before applying this skill, check the project's main instruction file such as `AGENTS.md`, `CLAUDE.md`, or equivalent.

Use this skill only when that file explicitly states the project uses Clean Architecture.

If the project does not explicitly state Clean Architecture, do not apply this skill.
Say that the Clean Architecture skill is not activated for this project, explain that the main project instructions do not explicitly state Clean Architecture, and do not introduce or show `UseCase`, `Port`, or `Adapter` classes or interfaces even as examples.

When this skill is active for an architecture or design review, also apply `php-solid-review` for cross-cutting engineering principles. Name only principles that explain material findings; its general heuristics must not override this skill's project-specific architectural boundaries.

## Boundaries

Preserve clear boundaries between use cases, domain/application logic, ports, and adapters.

Keep business rules out of technical adapters. Keep framework, transport, persistence, and client details out of application use cases.

Prefer dependency direction toward the domain or application core. Outer adapters should depend on ports and application models, not the other way around.

Ports should expose application-needed capabilities, not adapter assembly details. If a parameter exists only so a specific adapter can combine data from another source, inject that source into the adapter instead of leaking it through the port.

## Use Cases

Use cases should orchestrate business flow and delegate technical concerns to ports or cohesive collaborators.

Use cases receive already-validated input under [Validation Ownership](../php-request-validation/SKILL.md#validation-ownership) and [Request DTOs And Hydration](../php-request-validation/SKILL.md#request-dtos-and-hydration). Keep field checks and HTTP mode selection at input adapters; business-state decisions remain in the application/domain operation.

Avoid letting use cases accumulate unrelated creation, conversion, logging, key formatting, or client-specific responsibilities.

When orchestration becomes hard to read, extract cohesive factories, selectors, policies, or publishers with narrow names.

## Adapters And Clients

Around technical clients, prefer this flow where it fits naturally:

`ClientRequestFactory -> client call -> EntityFromResponseFactory`

Keep one-line response mappings inline when a response factory would not add clarity.

## Naming

Prefer names that reveal the architectural role: `UseCase`, `Port`, `Adapter`, `Factory`, `Policy`, `Selector`, or another established project term.

Do not introduce generic support classes when a specific architectural role is available.
