---
name: php-ddd-architecture
description: Use for PHP projects whose AGENTS.md, CLAUDE.md, or equivalent explicitly states DDD or Domain-Driven Design, especially domain/application/infrastructure boundaries, framework configuration placement, and web boundary naming.
---

# PHP DDD Architecture

## Activation Guard

Before applying this skill, check the project's main instruction file such as `AGENTS.md`, `CLAUDE.md`, or equivalent. Use it only when that file explicitly states the project uses DDD or Domain-Driven Design.

## Project Guidance

Follow the DDD rules in the project's own instruction files and domain docs.

- Preserve clear boundaries and responsibilities between domain concepts, application services, and infrastructure concerns.
- Ask for clarification before changing aggregates, entities, value objects, repositories, domain services, bounded-context language, or domain invariants when rules are missing or unclear.
- Prefer anemic domain models with behavior primarily in services unless there is a strong reason to keep logic on the entity itself.

## Framework Configuration

In DDD projects, treat framework configuration as infrastructure, not application or domain code.

- Put framework wiring and typed configuration holders under infrastructure configuration namespaces unless the project states a different convention.
- Use configuration classes only for framework wiring such as third-party clients, security, OpenAPI, and explicit service composition; keep classes focused and name them `<Thing>Configuration`.
- Use typed configuration holders only for property binding. Name them according to the project's established convention, keep them plain, validate required values with the project's boundary validation mechanism, and mark optional values with the project's nullability convention.
- If the framework or a third-party package owns a binding, document the exception at the class and keep the workaround local to infrastructure configuration.

## Web Boundaries

- Namespaces should expose the architectural side when known: end-user-facing code under frontend namespaces, backend/admin code under backend namespaces.
- Do not put side-specific controllers or services in a neutral application namespace when the side is known.
- Keep application-layer names aligned with existing route and UI vocabulary instead of inventing synonyms.
- Avoid ambiguous `Public...` and `Admin...` class prefixes when namespace boundaries or route vocabulary name the concept more clearly.
- Controller method names should mechanically mirror the HTTP route: HTTP verb prefix plus resource noun and optional route action.
- Keep domain verbs in services or use cases rather than controller method names.

## API Boundary Validation

Treat HTTP request shape as a web adapter concern, not a domain concern.

Validate transport-level input at the controller or API boundary: required query/path/body parameters, mutually required parameters, syntax, constraints supported by the project's boundary validation mechanism, endpoint-specific unsupported enum values, and HTTP status mapping.

Translate web DTOs, query parameters, and generated API models into application commands or purpose-named method calls before invoking application services. Do not pass nullable parameter combinations into application services to represent different HTTP request modes.

Only promote validation into the domain or application layer when it expresses a domain invariant in the bounded context's language and must hold for every caller, not just for one HTTP endpoint.

Do not create domain concepts or domain exceptions for malformed HTTP requests unless the same rule is genuinely part of the ubiquitous language.
