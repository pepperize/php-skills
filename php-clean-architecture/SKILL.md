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

Use cases should receive already-validated application input. Validate external input only in the input adapter layer. For typical PHP HTTP applications, use route middleware with Symfony Validator attributes on the input DTO as described in `php-request-validation`; controllers consume the validated DTO. Required values, types, lengths, formats, password character composition, allowed values, and cross-field input constraints belong there.

Avoid nullable parameter combinations inside a use case to choose between request modes. Prefer separate use-case methods, a purpose-named command object, or a small controller/API adapter decision.

Do not repeat field validation in use cases, services, application command constructors, domain objects, or repositories, or call an input-format rule a domain invariant to justify doing so. CLI, import, job, and external-system adapters validate their external input at their own entry boundaries before invoking use cases.

Keep business decisions requiring current state, including permissions, ownership, uniqueness, and lifecycle transitions, in their owning application/domain operation. For regex-based fields, use one full-value expression in the input contract, preferably shared with HTML5 `pattern`. Escape or encode at the actual output context.

Avoid letting use cases accumulate unrelated creation, conversion, logging, key formatting, or client-specific responsibilities.

When orchestration becomes hard to read, extract cohesive factories, selectors, policies, or publishers with narrow names.

## Adapters And Clients

Around technical clients, prefer this flow where it fits naturally:

`ClientRequestFactory -> client call -> EntityFromResponseFactory`

Keep one-line response mappings inline when a response factory would not add clarity.

## Naming

Prefer names that reveal the architectural role: `UseCase`, `Port`, `Adapter`, `Factory`, `Policy`, `Selector`, or another established project term.

Do not introduce generic support classes when a specific architectural role is available.
