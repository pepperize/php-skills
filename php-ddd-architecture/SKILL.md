---
name: php-ddd-architecture
description: Use for PHP projects whose AGENTS.md, CLAUDE.md, or equivalent explicitly states DDD or Domain-Driven Design, especially repository contracts, domain/application/infrastructure boundaries, framework configuration placement, web boundary naming, form-validation middleware, and Slim route URL generation.
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

For server-rendered form submission routes, perform request-body conversion and transport-level form validation in a route-specific PSR-15 middleware named `<FormName>ValidationMiddleware`.

- Convert the parsed request body into a typed `<FormName>Values` object through a factory.
- Validate those values and attach both `<FormName>Values` and `<FormName>ValidationResult` to the request as class-keyed attributes before delegating to the request handler.
- Let the controller require those attributes, render validation errors with the appropriate HTTP status, or invoke the application service with validated input.
- Do not inject form validators or form-values factories into controllers or run form validation directly inside controller actions.
- Treat missing or wrongly typed validation attributes in the controller as route-wiring errors and report them with `LogicException`.
- Attach the validation middleware only to the corresponding form-submission route.
- Keep response rendering and redirects in the controller; validation middleware prepares the request and does not render the form response.
- Keep domain invariants in the domain or application layer. Middleware owns HTTP request-shape validation and must not become the only enforcement point for rules that apply to every caller.

Avoid validation inside the controller:

```php
final class ContactController
{
    public function __construct(
        private ContactFormValuesFactory $valuesFactory,
        private ContactFormValidator $validator,
    ) {
    }

    public function postContact(
        ServerRequestInterface $request,
        ResponseInterface $response,
    ): ResponseInterface {
        $values = $this->valuesFactory->create((array) $request->getParsedBody());
        $validationResult = $this->validator->validate($values);

        // Rendering and application flow are now mixed with request validation.
    }
}
```

Put conversion and validation in route middleware:

```php
final class ContactFormValidationMiddleware implements MiddlewareInterface
{
    public function __construct(
        private ContactFormValuesFactory $valuesFactory,
        private ContactFormValidator $validator,
    ) {
    }

    public function process(
        ServerRequestInterface $request,
        RequestHandlerInterface $handler,
    ): ResponseInterface {
        $parsedBody = $request->getParsedBody();
        $requestBody = is_array($parsedBody) ? $parsedBody : [];
        $values = $this->valuesFactory->create($requestBody);
        $validationResult = $this->validator->validate($values);
        $validatedRequest = $request
            ->withAttribute(ContactFormValues::class, $values)
            ->withAttribute(ContactFormValidationResult::class, $validationResult);

        return $handler->handle($validatedRequest);
    }
}
```

The controller then owns only the HTTP outcome and application call:

```php
public function postContact(
    ServerRequestInterface $request,
    ResponseInterface $response,
): ResponseInterface {
    $values = $request->getAttribute(ContactFormValues::class);
    $validationResult = $request->getAttribute(ContactFormValidationResult::class);

    if (
        !$values instanceof ContactFormValues
        || !$validationResult instanceof ContactFormValidationResult
    ) {
        throw new LogicException('The contact route requires form validation.');
    }

    if ($validationResult->hasErrors()) {
        return $this->pageRenderer->renderForm(
            $response->withStatus(422),
            $values,
            $validationResult,
        );
    }

    $this->contactService->send($validationResult->message());

    return $this->responseFactory->createSuccess();
}
```

Register the middleware on the submission route:

```php
$app->post('/contact', [ContactController::class, 'postContact'])
    ->add(ContactFormValidationMiddleware::class);
```

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

Validate transport-level input at the web-adapter boundary: required query/path/body parameters, mutually required parameters, syntax, constraints supported by the project's boundary validation mechanism, endpoint-specific unsupported enum values, and HTTP status mapping. For server-rendered form submissions, follow the form-submission middleware convention above. Other HTTP endpoints may validate in the controller or a dedicated boundary validator when that matches the project's established architecture.

Translate web DTOs, query parameters, and generated API models into application commands or purpose-named method calls before invoking application services. Do not pass nullable parameter combinations into application services to represent different HTTP request modes.

Only promote validation into the domain or application layer when it expresses a domain invariant in the bounded context's language and must hold for every caller, not just for one HTTP endpoint.

Do not create domain concepts or domain exceptions for malformed HTTP requests unless the same rule is genuinely part of the ubiquitous language.
