---
name: php-api-endpoints
description: Implement, refactor, or review PHP REST resource endpoints using resource-named controllers and services, separate input and output DTOs, attribute-based validation, and focused repositories. Use for API endpoint work; server-rendered pages and traditional HTML form actions retain their own conventions.
---

# PHP API Endpoints

## Start With The User Reference

Before designing or editing a REST resource endpoint, read [the worked User endpoint](references/user-endpoint.md), starting with its [flow and naming explanation](references/user-endpoint.md#flow-and-naming). It captures the preferred `UserController`, `UserService`, `UserFactory`, `UserDtoFactory`, `UserRepository`, `User`, `UserDto` and `DoctrineUserRepository` organization, including validation and composition. Adapt the resource name, domain vocabulary, namespaces, supported operations and existing infrastructure to the target project.

Inspect project instructions first, classify the endpoint under [Endpoint Contracts](#endpoint-contracts), and use the [HTTP examples](../php-readable-code/references/http-endpoint-examples.md) for the corresponding composition.

## Responsibilities

This skill owns the backend resource flow: Controller -> Service -> Repository, with an optional technical Client behind the repository.

- Controllers consume typed, validated input, call the resource service, translate application failures through the existing HTTP error contract, and delegate response creation. They do not query repositories or map domain entities.
- Services coordinate business operations, entity construction, repository access, and public output construction. For creation, UserFactory::create(CreateUserRequest) constructs User; UserRepository::saveAndFlush(User) returns the authoritative persisted entity; UserDtoFactory::create(User) constructs the public UserDto returned by UserService::create().
- Repositories accept entities for persistence and return entities for entity results; lookups may accept identifiers or criteria. Request/output DTOs and technical client responses do not cross the entity-facing repository boundary. A repository using a Client maps its transport response to an entity inside infrastructure.
- Use an immutable input DTO and a separate output DTO so their accepted and returned contracts remain independent. For input ownership and sharing the validated instance with the service, follow [Request DTOs And Hydration](../php-request-validation/SKILL.md#request-dtos-and-hydration).
- Keep entity and output construction in the focused product factories. Ordinary ORM hydration does not require a second persistence model or an extra factory.
- Use [role suffixes](../php-readable-code/SKILL.md#backend-resource-flow), [REST API Naming](../php-readable-code/SKILL.md#rest-api-naming), and [Dependency Names](../php-readable-code/SKILL.md#dependency-names). Add only operations callers need; do not generate generic base services or unused CRUD.
- Keep hydration, constraint execution, and HTTP serialization distinct under [PHP Request Validation](../php-request-validation/SKILL.md#request-dtos-and-hydration); simple hydration may remain local when that contract permits it. Services and repositories consume validated input.

## Endpoint Contracts

Select conventions by the addressed endpoint's contract: REST resource operation, server-rendered page, traditional HTML form action, or another capability action. POST, JSON, JavaScript submission, and a server-rendered initial form do not establish resource creation by themselves.

A server-rendered form submitting to a REST resource endpoint follows that REST contract. JavaScript-managed submission does not turn a capability action into a REST resource operation. Preserve explicitly required compatibility and unrelated endpoint behavior. Use [REST API Naming](../php-readable-code/SKILL.md#rest-api-naming) and the [worked HTTP endpoint examples](../php-readable-code/references/http-endpoint-examples.md) for the corresponding names and compositions.

## HTTP Response Contract

- For a REST POST that completes resource creation, require all three: `201 Created`, a `Location` header identifying the created resource's canonical member URL, and a response body representing that resource, including its identifier and server-assigned public values. These are this skill collection's conventions; do not describe the mandatory body as an HTTP-standard requirement.
- Explicitly select response fields. Never serialize a domain entity wholesale or serialize the submitted input as the response; omit passwords, hashes, bearer tokens, and other secrets. Use the project's existing serializer/responder and response-mapping convention rather than inventing one for the example.
- Pending verification or another lifecycle state does not make completed resource creation asynchronous. Use `202 Accepted` only for an explicitly asynchronous contract whose processing has not completed. POST actions that do not create a resource and explicitly required existing compatibility contracts retain their own documented responses; flag a conflict with these defaults instead of silently treating it as the normal creation shape.
- The controller delegates the public DTO to the established response collaborator. That collaborator owns status, headers, canonical member URL generation including the configured base path, and JSON serialization; keep these HTTP mechanisms out of the resource service.

For an explicitly required traditional HTML form, follow [Traditional HTML Submissions](../php-request-validation/SKILL.md#traditional-html-submissions). Page rendering follows [Typed Page ViewModels](../php-templating/SKILL.md#typed-page-viewmodels).

## Persistence And Architecture

- Apply [PHP DDD Architecture](../php-ddd-architecture/SKILL.md#activation-guard) only when project instructions explicitly select it; its repository and web-boundary sections own the layer and namespace layout.
- In Doctrine projects using this pattern, prefer mapping attributes directly on domain entities and embedded values. Do not add a duplicate persistence record and mapping factory solely to keep mapping metadata outside the domain. Honor a project's explicit alternative mapping policy; this preference does not introduce Doctrine into another persistence stack.
- Doctrine attributes are permitted metadata; entity-manager configuration, connections, queries, transactions, persistence and flushing remain in infrastructure. Domain repository signatures use domain objects and ordinary contract types, without Doctrine APIs.
- Use `php-readable-code` repository operation names. `saveAndFlush(User $user): User` persists the supplied entity, flushes as promised and returns it with its assigned identifier. Choose other supported operations only when their actual callers need them.
- Translate proven conflicts through [Repository Conflict Exceptions](../php-logging-exceptions/SKILL.md#repository-conflict-exceptions); preserve causes and keep unrelated technical failures technical.

This reference supplies structure, not a registration product contract. Password rules, account verification, legal acknowledgements, email delivery, authorization and transaction semantics come from the actual project. Apply the corresponding PHP skills when that work is in scope; do not add those workflows merely because the example uses User.

## Verification And Self-Review

Use `php-testing-style` for affected tests and `php-solid-review` for non-trivial implementation self-review. Exercise the actual boundaries changed: invalid input stops before application work; the same validated DTO reaches the service; the public DTO comes from the persisted entity; completed creation has `201`, the correct member URL under the configured base path and no secrets; ORM attributes are loaded; and expected conflicts are translated without masking technical failures.

Trace the implemented roles before finalizing: input DTO -> entity factory -> entity repository -> output DTO factory, coordinated by the resource service and invoked by the controller. Verify the standard suffixes; explain any concrete different responsibility that needs another role. If a repository uses a client, keep technical transport and its response mapping behind the entity-facing repository contract.

For Slim argument-binding changes, use real dispatch to verify class-keyed delivery, missing/wrong-type `LogicException` before container fallback, and isolation across successive requests. Reuse the existing parser, validator, responder, invocation strategy, entity manager and repository bindings instead of creating parallel infrastructure.
