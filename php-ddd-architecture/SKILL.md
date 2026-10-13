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

## Authentication And Authorization Boundaries

In DDD projects, keep authentication mechanisms and the RBAC engine outside the domain and application model.

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
public function postBooking(ServerRequestInterface $request): ResponseInterface
{
    $currentUser = $this->currentUserFactory->createFromRequest($request);
    $command = $this->bookingCommandFactory->createFromRequest($request);

    $this->changeBooking->execute($currentUser, $command);

    return $this->responseFactory->createSuccess();
}
```

The use case may apply booking ownership or tenant rules with domain data. It must not inspect controller attributes or depend on the Laminas RBAC engine.

## Web Boundaries

- Namespaces should expose the architectural side when known: end-user-facing code under frontend namespaces, backend/admin code under backend namespaces.
- Do not put side-specific controllers or services in a neutral application namespace when the side is known.
- Keep application-service names aligned with the domain use case. For REST controllers and HTTP DTOs, apply `php-readable-code`: name the controller after the API resource and the request DTO after the operation and resource, such as `UserController` and `CreateUserRequest` for `POST /api/users`. UI or form vocabulary does not override REST naming.
- Avoid ambiguous `Public...` and `Admin...` class prefixes when namespace boundaries or route vocabulary name the concept more clearly.
- Controller method names should mechanically mirror the HTTP route: HTTP verb prefix plus resource noun and optional route action.
- Keep domain verbs in services or use cases rather than controller method names.

For server-rendered controllers, read the application-boundary examples in [references/repositories.md](references/repositories.md).

- Controllers must not depend directly on repositories. Introduce a frontend ViewService as the page-level presentation query.
- The ViewService must return the complete page-specific ViewModel consumed by the template. It coordinates domain-derived content with metadata and shared presentation components such as the site header and legal navigation.
- Perform repository access, domain-to-view mapping, and presentation transformations such as public email protection in the ViewService or a focused collaborator used by it. Do not expose domain entities, value objects, repository results, or infrastructure types through the page ViewModel.
- Obtain persisted or external domain data through repositories. A repository implementation may delegate technical communication to a client; the ViewService must not bypass the repository by depending on that client directly.
- Pass typed request-derived values such as `Locale` into the ViewService. Do not pass requests, responses, or renderers into it.
- Obtain shared component ViewModels through shared presentation collaborators. When a collaborator mainly constructs a ViewModel, name it `<Component>ViewModelFactory` and name its main operation `create(...)` or a purpose-revealing `createFor...(...)` variant.
- Route generation belongs to the frontend presentation boundary. A frontend ViewService or shared ViewModel factory may depend on `RouteParserInterface`; domain models, domain services, and repositories must not depend on it.
- Assign repository, service, and factory results to semantically named local variables before passing them to the page ViewModel constructor so each intermediate value remains easy to inspect in a debugger.
- The controller consumes typed request-derived input, calls one page ViewService, passes the returned page ViewModel to the established renderer, and completes the HTTP response with its status and headers. Keep the conventional `Renderer` name for a collaborator that renders a template and ViewModel into an HTML response body.
- Name a ViewService operation that performs repository or external I/O `fetchPage(...)`. Keep `get...` controller method names when `get` represents the HTTP verb.
- Before finalizing, verify that the controller contains no repository access or page-component construction, the ViewService returns the complete page ViewModel, domain-derived values came through repositories, and the renderer receives that page as the sole application-data input.

### Form Submission Validation

Default forms to JavaScript-managed submissions, including forms initially rendered by the server. The browser validates locally before submission, submits without navigating away, preserves inputs on failure, and owns displayed messages and their localization. Interpret actionable RFC 9457 Problem Details types or codes with frontend-owned feedback; never display server diagnostic text. Use `php-request-validation` for hydration, Symfony constraints, typed controller argument delivery, error mapping, and browser feedback.

- Perform request-body conversion and input validation in route-specific PSR-15 middleware, with Symfony Validator attributes on the input DTO. Name REST middleware after the request DTO, such as `CreateUserRequestValidationMiddleware`; use `<FormName>ValidationMiddleware` for traditional form endpoints.
- Convert accepted parsed input into the typed REST request DTO, such as `CreateUserRequest`, through the established factory. Reserve `<FormName>Values` for traditional form data. This distinction still applies when a browser form submits to the REST API. Keep factories and validators out of controllers.
- On parsing or validation failure, return Problem Details with `Content-Type: application/problem+json` through the shared error infrastructure without invoking the next handler: malformed syntax is HTTP 400 and contract violations are HTTP 422. Invalid submissions must not reach the controller or application operations.
- On success, attach the validated request DTO as a class-keyed request attribute and delegate with the returned request.
- In Slim projects, prefer a controller parameter containing the validated DTO, resolved by declared type from its class-keyed attribute using `php-request-validation` and its Slim controller-arguments reference. Keep invocation strategies, parameter resolvers, and their composition in infrastructure. Missing or wrongly typed required DTOs must raise `LogicException` at the invocation boundary before container fallback. The controller translates the DTO into application-owned input, invokes the application service, and produces the established success response; it keeps `ServerRequestInterface` only when other request data is needed.
- Attach the validation middleware only to the corresponding submission route. Keep hydration, field validation, and HTTP serialization in the web/infrastructure input boundary. Services and domain objects consume validated input without repeating field checks; state-dependent business rules remain in their owning operations.

For example, register contact validation explicitly:

```php
$app->post('/contact', [ContactController::class, 'postContact'])
    ->add(ContactFormValidationMiddleware::class);
```

Only when the project or task explicitly requires an ordinary HTML submission, keep the controller-rendered error flow: middleware attaches both `<FormName>Values` and `<FormName>ValidationResult` as class-keyed attributes on either outcome and delegates. In Slim, prefer delivering both as typed controller parameters through the same invocation boundary, which reports missing or wrongly typed required attributes with `LogicException`. The controller renders invalid forms with preserved values and the appropriate status, and invokes application operations only after successful validation. Middleware must not render the HTML form itself. Do not add this fallback by default.

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

Treat HTTP request shape as a web adapter concern, not a domain concern.

Validate external input only at its input boundary: required query/path/body parameters, mutually required parameters, types, lengths, formats, password character composition, allowed input values, and cross-field constraints. In typical PHP HTTP applications, use route middleware with Symfony Validator attributes on the input DTO as described in `php-request-validation`. Preserve established validation on unrelated endpoints and use the framework's equivalent input boundary when PSR-15 is unavailable.

Translate web DTOs, query parameters, and generated API models into application commands or purpose-named method calls before invoking application services. Do not pass nullable parameter combinations into application services to represent different HTTP request modes.

Do not promote or repeat input validation in application services, domain services, entities, value objects, command constructors, or repositories. Calling a field-format rule a domain invariant does not change its input-layer ownership. CLI commands, imports, jobs, and external-system adapters validate at their own entry boundaries; do not add service revalidation for hypothetical callers.

Keep state-dependent business decisions, including permissions, ownership, uniqueness, and lifecycle transitions, in the application/domain operation that owns them. Do not create domain concepts or domain exceptions for malformed external input.

For regex-based fields, use one full-value expression in the input contract, preferably shared with frontend HTML5 `pattern`; follow `php-request-validation` for engine adaptation. Keep pattern constants out of domain policies created solely for input validation. Escape or encode at the final output context, not while creating application input.
