---
name: php-ddd-architecture
description: Use for PHP projects whose AGENTS.md, CLAUDE.md, or equivalent explicitly states DDD or Domain-Driven Design, especially repository contracts, domain/application/infrastructure boundaries, framework configuration placement, web boundary naming, form-validation middleware, and Slim route URL generation.
---

# PHP DDD Architecture

## Activation Guard

Before applying this skill, check the project's main instruction file such as `AGENTS.md`, `CLAUDE.md`, or equivalent. Use it only when that file explicitly states the project uses DDD or Domain-Driven Design.

When this skill is active for an architecture or design review, also apply `php-solid-review` for cross-cutting engineering principles. Name only principles that explain material findings; its general heuristics must not override this skill's project-specific DDD rules.

## Project Guidance

Follow the DDD rules in the project's own instruction files and domain docs.

- Preserve clear boundaries and responsibilities between domain concepts, application services, and infrastructure concerns.
- Ask for clarification before changing aggregates, entities, value objects, repositories, domain services, bounded-context language, or domain invariants when rules are missing or unclear.
- Prefer anemic domain models with behavior primarily in services unless there is a strong reason to keep logic on the entity itself.

## Repository Contracts

When adding, reviewing, or refactoring a repository, read [references/repositories.md](references/repositories.md) before editing.

- Treat an abstraction that retrieves domain objects as a repository regardless of whether its data comes from a database, file, source-controlled data, memory, or external service.
- Define the repository interface in the domain module that owns the returned model. Keep the returned model in that domain module as well.
- Domain repository contracts and models must not depend on application, frontend, framework, transport, persistence, or infrastructure APIs. The [Doctrine mapping policy](../php-api-endpoints/SKILL.md#persistence-and-architecture) permits mapping metadata on domain models; ORM operations stay in infrastructure.
- Put repository implementations in infrastructure. Implementation names may identify their storage mechanism, such as `FilePrivacyPolicyVersionRepository` or `InMemoryForwardingRecipientRepository`.
- Application services depend on domain repository interfaces. Controllers depend on application services rather than repositories. Framework composition binds repository interfaces to their infrastructure implementations.
- For resource operations, follow [API Responsibilities](../php-api-endpoints/SKILL.md#responsibilities). Keep factories that accept application DTOs in application code and transport-to-entity factories in infrastructure; domain entities and repository contracts must not depend on either.
- Use the ubiquitous domain name. Do not introduce a presentation-owned duplicate when several workflows use the same concept.
- Do not name a domain-object retrieval abstraction `Provider`, `Loader`, or `Reader`. Those names remain valid for collaborators whose responsibility is configuration binding, serialization, transport, or another non-repository concern.
- Expose only operations required by callers. Do not introduce a generic base repository or speculative write or query methods.
- For entity-exists failures, follow [Repository Conflict Exceptions](../php-logging-exceptions/SKILL.md#repository-conflict-exceptions) with a shared domain `EntityExistsException` owned by the repository contract.

Follow [Repository Method Naming](../php-readable-code/SKILL.md#repository-method-naming) in `php-readable-code` for read and write operation names. Keep these retrieval and absence conventions:

- Singular reads use `find(...)` or criteria-based `findOneBy(...)` and return the declared object type.
- When the requested object does not exist, `find(...)` and `findOneBy(...)` throw the domain `NotFoundException`; they do not return `null`.
- Collection reads use `findAll()` or criteria-based `findBy(...)` and document their element type as a list.
- When no matching objects exist, `findAll()` and `findBy(...)` return `[]`; they do not throw `NotFoundException` merely because the result is empty.
- Do not repeat the repository subject in method names. Prefer `LegalOperatorRepository::find()` over `LegalOperatorRepository::findLegalOperator()`.
- Report absence as `NotFoundException`. Keep failures reading or decoding an existing data source as technical exceptions.

Before finalizing, verify that repository interfaces and their returned types are owned by the domain, implementations are owned by infrastructure, and nothing under the domain namespace depends outward on application or infrastructure namespaces.

## Framework Configuration

In DDD projects, treat framework configuration as infrastructure, not application or domain code.

- Put framework wiring and typed configuration holders under infrastructure configuration namespaces unless the project states a different convention.
- Use configuration classes only for framework wiring such as third-party clients, security, OpenAPI, and explicit service composition; keep classes focused and name them `<Thing>Configuration`.
- Use typed configuration holders only for property binding. Name them according to the project's established convention, keep them plain, validate required values with the project's boundary validation mechanism, and mark optional values with the project's nullability convention.
- If the framework or a third-party package owns a binding, document the exception at the class and keep the workaround local to infrastructure configuration.

## Authentication And Authorization Boundaries

In DDD projects, keep authentication mechanisms and the RBAC engine outside the domain and application model.

This section owns DDD placement. Use [PHP Authentication Security](../php-authentication-security/SKILL.md) and [Authorization Boundary](../php-rbac-authorization/SKILL.md#authorization-boundary) for the complete security contracts; the checks below retain the layer-boundary reminders.

- Keep concrete Mezzio authentication and authorization interfaces, middleware, request attributes, session adapters, Laminas RBAC objects, factories, and package configuration in infrastructure or the web adapter.
- Let the application own `CurrentUser`, `AuthorizationService`, the `Permission` enum, and typed `RequiresAuthentication` and `RequiresPermission` attribute contracts.
- Map the Mezzio identity to `CurrentUser` at the web boundary. Do not pass `Mezzio\Authentication\UserInterface`, a PSR-7 request, session objects, or `Laminas\Permissions\Rbac\Rbac` into application or domain services.
- Apply authentication and permission attributes only to public controller methods. Application and domain services must remain free of controller authorization metadata.
- Keep role-to-permission configuration in infrastructure while keeping permission names in the application vocabulary.
- Keep ownership, tenant scope, lifecycle rules, and privilege-change invariants in application policies or domain services where the relevant objects and transaction are available.
- Use the RBAC result for the coarse capability and a separate application or domain decision for object scope. Do not encode aggregate identifiers into permission strings.

For example, translate the framework identity once and call application code with the application-owned type:

```php
#[RequiresPermission(Permission::BookingWrite)]
public function postBooking(
    ChangeBookingRequest $changeBookingRequest,
    ServerRequestInterface $request,
): ResponseInterface {
    $currentUser = $this->currentUserFactory->createFromRequest($request);

    $this->changeBooking->execute($currentUser, $changeBookingRequest);

    return $this->responseFactory->createSuccess();
}
```

Validation middleware supplies `ChangeBookingRequest` through the established typed controller-argument boundary. The identity factory maps the authenticated user, and the controller passes the same validated DTO to the use case. The use case may apply booking ownership or tenant rules with domain data. It must not inspect controller attributes or depend on the Laminas RBAC engine.

## Web Boundaries

- For REST endpoints, apply [PHP API Endpoints](../php-api-endpoints/SKILL.md) and read its worked User reference. By default, group API controllers, services, DTOs, and factories under `App/Api/<Resource>`; reserve `App/Frontend` for rendered interfaces and traditional HTML actions. Preserve an explicit alternative project layout rather than adding a fourth presentation layer.
- Use [REST API Naming](../php-readable-code/SKILL.md#rest-api-naming) for resource vocabulary and CRUD names, and [API HTTP Response Contract](../php-api-endpoints/SKILL.md#http-response-contract) for completed creation. Reminder: the service returns the persisted entity's public DTO; the controller delegates 201, member Location, and representation to its responder.
- Avoid ambiguous Public... and Admin... prefixes when namespaces or route vocabulary name the concept more clearly.
- Controller methods mechanically mirror the HTTP verb, resource noun, and optional route action; keep domain verbs in services or use cases.

For rendered controllers, read the [application-boundary examples](references/repositories.md) and apply [Typed Page ViewModels](../php-templating/SKILL.md#typed-page-viewmodels).

- Controllers depend on frontend ViewServices rather than repositories. The complete page ViewModel and rendering contract are owned by PHP Templating; do not assemble page components in the controller.
- ViewServices obtain persisted or external domain data through domain repositories. A repository may use a technical Client internally; the ViewService must not bypass it by calling that client directly.
- Keep domain objects and infrastructure types behind the presentation mapping boundary. Use typed request-derived values, shared component factories, and visible intermediate values under the linked presentation and naming rules.
- Route generation belongs to frontend presentation collaborators, never domain models, domain services, or repositories; follow the Slim section below.

### Form Submission Validation

[PHP Request Validation](../php-request-validation/SKILL.md#validation-ownership) owns DTO constraints, hydration, middleware delivery, and [Browser Forms](../php-request-validation/SKILL.md#browser-forms). Reminder: validate locally, preserve inputs, and display frontend-owned messages rather than server diagnostics.

Keep route validation middleware, invocation strategies, parameter resolvers, and their composition in infrastructure. Register validation only on the corresponding submission route:

```php
$app->post('/contact', [ContactController::class, 'postContact'])
    ->add(ContactFormValidationMiddleware::class);
```

Ordinary HTML actions use [Traditional HTML Submissions](../php-request-validation/SKILL.md#traditional-html-submissions) only when explicitly required. Keep their HTML error/redirect contract distinct from REST responses.

### Slim Route URL Generation

When a Slim controller or web adapter generates route URLs, read [references/slim-route-url-generation.md](references/slim-route-url-generation.md) before editing.

- Inject `Slim\Interfaces\RouteParserInterface` as a required constructor dependency of the frontend presentation collaborator that owns the generated URLs.
- Do not obtain the route parser through `RouteContext::fromRequest($request)->getRouteParser()` or another request-scoped lookup.
- Register `RouteParserInterface` once in infrastructure composition using the application's route collector.
- Remove `ServerRequestInterface` parameters that existed only to obtain the route parser. Keep the request when the action reads headers, attributes, query parameters, the URI, or other request data.
- Preserve existing route names and route arguments during this refactor.
- Do not introduce a project-owned URL-generator abstraction unless the existing architecture already defines one.
- Keep Slim route generation in frontend presentation collaborators such as controllers, ViewServices, or ViewModel factories. Do not pass the route parser into domain models, domain services, or repositories.
- In unit tests, mock `RouteParserInterface` directly at the collaborator that owns URL generation and verify route names and arguments when those interactions are the behavior under test. Do not construct a Slim request or attach `RouteContext` solely to provide URL generation. HTTP integration tests may still use requests to exercise routing and dispatch.

Before finalizing Slim URL-generation changes, search production code and tests for `RouteContext` and `getRouteParser()`. Verify that request-scoped route-parser lookup is gone, `getRouteParser()` remains only in infrastructure composition, and integration tests cover route names, base paths, and generated URLs.

## API Boundary Validation

Treat HTTP request shape as a web adapter concern. [Validation Ownership](../php-request-validation/SKILL.md#validation-ownership) owns input-only field checks; [Request DTOs And Hydration](../php-request-validation/SKILL.md#request-dtos-and-hydration) owns shared application DTOs, one-time normalization, and actual contract differences.

Keep hydration, validation execution, invocation infrastructure, and error serialization in the web/infrastructure input boundary. Domain objects and services consume validated input; state-dependent business decisions remain with their owning operation.
