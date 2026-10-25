---
name: php-api-endpoints
description: Implement, refactor, or review PHP REST resource endpoints using resource-named controllers and services, separate input and output DTOs, attribute-based validation, and focused repositories. Use for API endpoint work; server-rendered pages and traditional HTML form actions retain their own conventions.
---

# PHP API Endpoints

## Start With The User Reference

Before designing or editing a REST resource endpoint, read [the worked User endpoint](references/user-endpoint.md), starting with its [flow and naming explanation](references/user-endpoint.md#flow-and-naming). It captures the preferred `UserController`, `UserService`, `UserFactory`, `UserDtoFactory`, `UserRepository`, `User`, `UserDto` and `DoctrineUserRepository` organization, including validation and composition. Adapt the resource name, domain vocabulary, namespaces, supported operations and existing infrastructure to the target project.

Inspect the endpoint contract and project instructions first. Do not infer REST resource creation from POST, JSON, or a browser form alone. Use [HTTP endpoint contracts](../php-readable-code/references/http-endpoint-examples.md) to distinguish APIs from HTML pages and capability actions. Preserve explicit compatibility requirements.

## Responsibilities

- Follow the [backend resource flow](../php-readable-code/SKILL.md#backend-resource-flow): `Controller -> Service -> Repository`, optionally `Repository -> Client`. Services accept and return application DTOs for resource operations; repositories persist and return entities, with identifiers or criteria for lookups. Keep request/output DTOs and technical client responses out of repository entity contracts.
- Keep the resource name through controller, service, DTO and repository. Use supported `create`, `read`, `update` and `delete` service operations; do not generate unused CRUD methods or generic base classes.
- Use an immutable operation/resource request DTO, such as `CreateUserRequest`, distinct from the output-only `UserDto`. The controller passes the same validated input instance directly to the typed service parameter unless an actual contract difference requires mapping.
- Keep input hydration, Symfony execution and typed error mapping, and HTTP serialization as distinct responsibilities. Route validation middleware should reveal construction, constraint validation and dispatch; simple hydration may be a focused private method rather than a required hydration-result factory. Follow `php-request-validation` when choosing between local construction, a separate collaborator and an error-collecting result. Reuse established collaborators when required by the task, and preserve the actual contract for normalization, unknown fields, error accumulation, locale selection and parser/protection guarantees.
- Declare Symfony constraints as attributes on the input DTO and execute them once in the input boundary. Use `php-request-validation` for hydration, middleware, typed argument delivery, Problem Details and browser feedback. Services, entities and repositories do not repeat field validation or normalization.
- Keep the controller thin: consume typed input, call the resource service, translate application failures into the existing HTTP error contract, and delegate response creation. Controllers do not query repositories or map domain entities.
- Let the resource service coordinate business operations, factories and repository access. Use a focused `UserFactory::create(CreateUserRequest): User` for input DTO-to-entity construction and `UserDtoFactory::create(User): UserDto` for output construction from the authoritative persisted entity. Return that public DTO; keep construction in the factories. Services do not choose HTTP statuses or headers, generate URLs, or serialize JSON.
- Let `UserResponseFactory` or the established responder own HTTP output. Completed creation returns `201`, the created member's canonical `Location`, and the DTO representation including its identifier and public server-assigned values. Explicitly select output fields and omit secrets; do not serialize the entity or submitted request wholesale.
- Follow `php-readable-code` for method and dependency names. Injected dependencies use the declared short type in lower camel case after dropping a trailing `Interface`, while preserving role suffixes such as `Repository` and `Factory`.

## Persistence And Architecture

- Apply `php-ddd-architecture` only when project instructions explicitly select DDD. In that layout, keep entities and repository contracts in their owning domain module, API collaborators under `App/Api/<Resource>`, and repository implementations and framework composition in infrastructure. Honor an explicitly different project layout.
- In Doctrine projects using this pattern, prefer mapping attributes directly on domain entities and embedded values. Do not add a duplicate persistence record and mapping factory solely to keep mapping metadata outside the domain. Honor a project's explicit alternative mapping policy; this preference does not introduce Doctrine into another persistence stack.
- Doctrine attributes are permitted metadata; entity-manager configuration, connections, queries, transactions, persistence and flushing remain in infrastructure. Domain repository signatures use domain objects and ordinary contract types, without Doctrine APIs.
- Use `php-readable-code` repository operation names. `saveAndFlush(User $user): User` persists the supplied entity, flushes as promised and returns it with its assigned identifier. Choose other supported operations only when their actual callers need them.
- Use `php-logging-exceptions` for conflict translation: established storage conflict → contract-owned `EntityExistsException` → resource-specific application exception → HTTP boundary failure, preserving each cause. Unrelated storage or integrity failures remain technical; do not classify conflicts by parsing exception messages.

This reference supplies structure, not a registration product contract. Password rules, account verification, legal acknowledgements, email delivery, authorization and transaction semantics come from the actual project. Apply the corresponding PHP skills when that work is in scope; do not add those workflows merely because the example uses User.

## Verification And Self-Review

Use `php-testing-style` for affected tests and `php-solid-review` for non-trivial implementation self-review. Exercise the actual boundaries changed: invalid input stops before application work; the same validated DTO reaches the service; the public DTO comes from the persisted entity; completed creation has `201`, the correct member URL under the configured base path and no secrets; ORM attributes are loaded; and expected conflicts are translated without masking technical failures.

Trace the implemented roles before finalizing: input DTO -> entity factory -> entity repository -> output DTO factory, coordinated by the resource service and invoked by the controller. Verify the standard suffixes; explain any concrete different responsibility that needs another role. If a repository uses a client, keep technical transport and its response mapping behind the entity-facing repository contract.

For Slim argument-binding changes, use real dispatch to verify class-keyed delivery, missing/wrong-type `LogicException` before container fallback, and isolation across successive requests. Reuse the existing parser, validator, responder, invocation strategy, entity manager and repository bindings instead of creating parallel infrastructure.
