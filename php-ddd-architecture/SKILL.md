---
name: php-ddd-architecture
description: Use for PHP projects whose AGENTS.md, CLAUDE.md, or equivalent explicitly states DDD or Domain-Driven Design, especially repository contracts, domain/application/infrastructure boundaries, framework configuration placement, web boundary naming, and Slim route URL generation.
---

# PHP DDD Architecture

## Activation Guard

Before applying this skill, check the project's main instruction file such as `AGENTS.md`, `CLAUDE.md`, or equivalent. Use it only when that file explicitly states the project uses DDD or Domain-Driven Design.

## Project Guidance

Follow the DDD rules in the project's own instruction files and domain docs.

- Preserve clear boundaries and responsibilities between domain concepts, application services, and infrastructure concerns.
- Ask for clarification before changing aggregates, entities, value objects, repositories, domain services, bounded-context language, or domain invariants when rules are missing or unclear.
- Prefer anemic domain models with behavior primarily in services unless there is a strong reason to keep logic on the entity itself.

## Repository Contracts

When adding, reviewing, or refactoring a repository, read [references/repositories.md](references/repositories.md) before editing.

- Treat an abstraction that retrieves domain objects as a repository regardless of whether its data comes from a database, file, source-controlled data, memory, or external service.
- Define the repository interface in the domain module that owns the returned model. Keep the returned model in that domain module as well.
- Domain repository contracts and models must not depend on application, frontend, framework, transport, persistence, or infrastructure types.
- Put repository implementations in infrastructure. Implementation names may identify their storage mechanism, such as `FilePrivacyPolicyVersionRepository` or `InMemoryForwardingRecipientRepository`.
- Application services depend on domain repository interfaces. Controllers depend on application services rather than repositories. Framework composition binds repository interfaces to their infrastructure implementations.
- Use the ubiquitous domain name. Do not introduce a presentation-owned duplicate when several workflows use the same concept.
- Do not name a domain-object retrieval abstraction `Provider`, `Loader`, or `Reader`. Those names remain valid for collaborators whose responsibility is configuration binding, serialization, transport, or another non-repository concern.
- Expose only operations required by callers. Do not introduce a generic base repository or speculative `save`, `remove`, or query methods.

Use these retrieval and absence conventions:

- A repository operation returning one object is named `find(...)` and returns the declared object type.
- When the requested object does not exist, `find(...)` throws the domain `NotFoundException`; it does not return `null`.
- A repository operation returning a list is named `findAll(...)` and documents its element type as a list.
- When no matching objects exist, `findAll(...)` returns `[]`; it does not throw `NotFoundException` merely because the result is empty.
- Do not repeat the repository subject in method names. Prefer `LegalOperatorRepository::find()` over `LegalOperatorRepository::findLegalOperator()`.
- Report absence as `NotFoundException`. Keep failures reading or decoding an existing data source as technical exceptions.

Before finalizing, verify that repository interfaces and their returned types are owned by the domain, implementations are owned by infrastructure, and nothing under the domain namespace depends outward on application or infrastructure namespaces.

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

For server-rendered controllers, read the application-boundary examples in [references/repositories.md](references/repositories.md).

- Controllers must not depend directly on repositories. Introduce a frontend application service that coordinates repository access.
- The service must return a feature-specific presentation ViewModel containing only the data required by the page content. Do not return domain entities, value objects, repository results, or infrastructure types to the controller or template.
- Perform domain-to-view mapping and presentation transformations, such as public email protection, in the frontend service.
- The controller composes the content ViewModel with request-specific page ViewModels such as metadata, header navigation, and legal navigation, then passes the resulting page ViewModel to the renderer.
- Keep request parsing, route URL generation, response rendering, status codes, and response headers in the controller.
- Do not pass requests, responses, route parsers, renderers, or other framework objects into the service.
- Name service operations that perform repository or external I/O with `fetch...`, such as `fetchContent()`. Keep `get...` controller method names when `get` represents the HTTP verb.
- Before finalizing, verify that controller constructors contain no repository dependencies, domain-derived render values come from the service ViewModel, and route-derived values are composed into the page ViewModel by the controller.

### Slim Route URL Generation

When a Slim controller or web adapter generates route URLs, read [references/slim-route-url-generation.md](references/slim-route-url-generation.md) before editing.

- Inject `Slim\Interfaces\RouteParserInterface` as a required constructor dependency.
- Do not obtain the route parser through `RouteContext::fromRequest($request)->getRouteParser()` or another request-scoped lookup.
- Register `RouteParserInterface` once in infrastructure composition using the application's route collector.
- Remove `ServerRequestInterface` parameters that existed only to obtain the route parser. Keep the request when the action reads headers, attributes, query parameters, the URI, or other request data.
- Preserve existing route names and route arguments during this refactor.
- Do not introduce a project-owned URL-generator abstraction unless the existing architecture already defines one.
- Keep Slim route generation in controllers or web adapters. Do not pass the route parser into domain or application services.
- In unit tests, mock `RouteParserInterface` directly and verify route names and arguments. Do not construct a Slim request or attach `RouteContext` solely to provide URL generation. HTTP integration tests may still use requests to exercise routing and dispatch.

Before finalizing Slim URL-generation changes, search production code and tests for `RouteContext` and `getRouteParser()`. Verify that request-scoped route-parser lookup is gone, `getRouteParser()` remains only in infrastructure composition, and controller integration tests cover route names, base paths, and generated URLs.

## API Boundary Validation

Treat HTTP request shape as a web adapter concern, not a domain concern.

Validate transport-level input at the controller or API boundary: required query/path/body parameters, mutually required parameters, syntax, constraints supported by the project's boundary validation mechanism, endpoint-specific unsupported enum values, and HTTP status mapping.

Translate web DTOs, query parameters, and generated API models into application commands or purpose-named method calls before invoking application services. Do not pass nullable parameter combinations into application services to represent different HTTP request modes.

Only promote validation into the domain or application layer when it expresses a domain invariant in the bounded context's language and must hold for every caller, not just for one HTTP endpoint.

Do not create domain concepts or domain exceptions for malformed HTTP requests unless the same rule is genuinely part of the ubiquitous language.
