---
name: php-readable-code
description: Use when writing, refactoring, or reviewing PHP production code around readability, responsibilities, naming, REST API resource/controller/DTO naming, guard clauses, factories, utilities, nullable collections, or test-only production code.
---

# PHP Readable Code

## Default Style

- Prefer small focused classes, explicit responsibilities, intention-revealing names, readable control flow, and minimal incidental complexity.
- Prefer GoF design patterns where they fit naturally.
- Avoid broad utility classes that mix unrelated concerns such as creation, mapping, conversion, logging, and key formatting; extract cohesive collaborators with narrow names instead.
- Avoid passing non-trivial method calls directly as arguments when an intermediate variable would clarify intent. Name semantically important intermediate results.
- Prefer simple, common words that non-native speakers can read without looking them up.

## Dependency Names

Name each injected dependency after its complete declared short type, converted to lower camel case. Preserve role suffixes such as `Repository`, `Factory`, `Generator`, `Service`, `Client`, and `Interface`; they distinguish the collaborator from the values it returns.

```php
private PublicUrlGenerator $publicUrlGenerator;
private ApartmentLayoutRepository $apartmentLayoutRepository;
private LocalizedApartmentLayoutFactory $localizedApartmentLayoutFactory;
```

Never replace the type-derived name of a single dependency with a plural resource noun such as `$publicUrls`, `$apartmentLayouts`, or `$localizedApartmentLayouts`. Use plural names for actual collections.

## Debuggable Composition

When constructing an aggregate result such as a page ViewModel, assign each repository, service, or factory result to a semantically named local variable before passing it to the constructor. Do not inline these collaborator calls as constructor arguments. The local variables must make intermediate values and types directly inspectable in an IDE or debugger. Literals and already-available variables may still be passed directly.

Avoid hiding collaborator results inside the final construction:

```php
return new PrivacyPolicyPageViewModel(
    new PageMetadataViewModel($locale, 'Privacy policy'),
    $this->siteHeaderFactory->createForLegalPage($locale, 'privacy-policy'),
    $this->fetchContent(),
    $this->legalNavigationFactory->create($locale, 'privacy-policy'),
);
```

Keep each meaningful intermediate result visible:

```php
$metadata = new PageMetadataViewModel($locale, 'Privacy policy');
$header = $this->siteHeaderFactory->createForLegalPage($locale, 'privacy-policy');
$content = $this->fetchContent();
$legalNavigation = $this->legalNavigationFactory->create($locale, 'privacy-policy');

return new PrivacyPolicyPageViewModel(
    $metadata,
    $header,
    $content,
    $legalNavigation,
);
```

## Guard Clauses

- Do not use assertion utilities in application, domain, or service code to enforce business conditions.
- Prefer explicit guard clauses with normal `if` statements and meaningful exceptions.
- Inside business logic, prefer explicit checks over assertion utilities.

## Validation Placement

Validate external input only in the input layer. For typical PHP HTTP projects, declare constraints as Symfony attributes on the input DTO and execute them in route middleware using `php-request-validation`. Controllers consume validated input; services, application commands, domain/value-object constructors, repositories, and output code must not repeat field checks.

Required values, nullness, blank strings, size, syntax, password character composition, allowed input values, nested DTOs, and cross-field input constraints belong there. Do not introduce a policy, predicate, specification, or `Service::validate()` merely to restate those rules or protect hypothetical future callers. CLI, import, job, and external-system inputs are validated at their own entry boundaries.

Use one full-value regex per field when regex is needed, preferably sharing its canonical body with HTML5 `pattern`. Do not split the field's character requirements across regex attributes or downstream `preg_match()` calls. Keep built-in constraints for the rules they express clearly; follow `php-request-validation` and `php-application-security` for sharing and engine safety.

Use a focused custom input validator only when built-in constraints cannot express the input contract clearly; invoke it from the input layer and keep it side-effect free. Leave HTTP mapping to the boundary's existing responder.

Business decisions about permissions, ownership, uniqueness, and lifecycle transitions stay in their owning operation and use explicit guard clauses. Do not classify a stateless field-format check as a business invariant to bypass the input-layer rule. Escape or encode values at their final output context rather than altering validated or stored values.

## Factories

When a class mainly creates a returned object, prefer the Factory pattern: name the class after the product plus `Factory`, and name the main method `create(...)`.

## REST API Naming

- For new or intentionally redesigned REST endpoints, name resource collections with plural nouns from the domain language. Let the HTTP method express the operation: `POST /api/users` creates a user; `GET /api/users/{userId}` reads a user.
- Choose the resource actually created or addressed. Do not name a user-creation endpoint after its registration form, controller, or workflow. Use `/api/registrations` only when a registration is itself a domain resource with its own identity and lifecycle.
- Name REST controllers after the addressed domain resource: `UserController` handles `/api/users`. Controller methods mirror the HTTP verb and route resource, such as `postUsers()` and `getUsers()`. Do not name a REST controller after the registration form or workflow.
- Name REST request DTOs after the operation and resource with a `Request` suffix: `CreateUserRequest` is the body of `POST /api/users`. Reserve names such as `RegistrationValues` or `UserCreationValues` for traditional form data. A browser form calling a REST API still uses REST request naming.
- Prefer separate request and response DTOs so accepted input and returned output have independent contracts. Use names such as `CreateUserRequest` and `CreateUserResponse`, or `UserResponse` for a returned user representation. A shared `UserDto` is admissible when the same object deliberately represents both request and response; do not default to sharing it. These HTTP DTOs remain distinct from the domain entity `User`.
- Application services and frontend methods may retain capability names such as `RegistrationService` and `register()`; that does not justify workflow names for REST controllers or request DTOs.
- Treat a request to refactor a REST endpoint according to this skill as including corrections to its route, controller, and DTO names. Preserve explicitly required compatibility and unrelated API behavior; do not silently exclude naming corrections just because the old names already exist. Update routes, clients, tests, and contract documentation together. Do not add compatibility aliases without a caller or contract that requires them.

For a registration flow that creates a `User`:

| Good | Bad | Reason |
| --- | --- | --- |
| `POST /api/users` | `POST /api/registration` | The collection names the created domain resource rather than the workflow. |
| `POST /api/users` | `POST /api/registerUser` | The HTTP method expresses the operation rather than an action in the path. |
| `GET /api/users/{userId}` | `GET /api/user/{userId}` | A member remains addressed under the plural resource collection. |
| `UserController::postUsers()` | `RegistrationController::postRegistration()` | The controller names the resource and the handler mirrors the HTTP route. |
| `CreateUserRequest` | `RegistrationValues`, `UserCreationValues` | A REST request body names the operation and resource rather than form values. |
| Separate `CreateUserRequest` and `CreateUserResponse` | Automatically sharing a `UserDto` | Input and output contracts can evolve independently. |

## Method Names

- Methods should read as actions. Prefer verb phrases such as `createMissingTranslationSkip`, `collectRoutes`, `resolveCountryCode`, or `publishSeoData`.
- Do not repeat information already carried by the class name, receiver, or return type unless it distinguishes variants or avoids ambiguity at call sites. Prefer `DataFactory::create()` over `DataFactory::createData()`.
- Avoid noun/adjective-only method names like `missingTranslation(...)` unless the method is an accessor, enum/value property, or boolean predicate.
- Boolean predicates should still read clearly as questions or states, using `is`, `has`, `can`, `should`, or similar.
- Static factory methods should also use an action-oriented name unless they follow an established PHP or project convention such as `from(...)`.
- Before accepting new or renamed methods, classify each one as an accessor/property, boolean predicate, action/operation, or factory/construction helper. Accessors should use noun or state names such as `status()`, `totalCount()`, `successCount()`, or `failureCount()`. Boolean predicates should read as predicates, such as `isSuccess()` or `hasFailures()`. Action, operation, and factory helper methods must use verb phrases. Avoid past-tense or adjective helper names such as `succeeded(...)`, `failed(...)`, `missingTranslation(...)`, or `partialSuccess(...)` when the method creates, transforms, or returns a result; prefer names such as `createSuccessResult(...)`, `createFailureResult(...)`, `resolveStatus()`, or `collectFailures(...)`.

### Fetching Data

- Use `fetch...` for application-service operations that perform repository, filesystem, network, or other potentially costly I/O. Do not name these operations `get...`, because `get` suggests a cheap accessor.
- Prefer a purpose-revealing name such as `fetchViewData()` over a generic `fetch()`.
- HTTP controller methods may retain names such as `getPrivacyPolicy()` when `get` represents the HTTP verb.

```php
$viewData = $privacyPolicyViewService->fetchViewData(); // Repository access: correct.
$viewData = $privacyPolicyViewService->getViewData();   // Repository access: misleading.

$controller->getPrivacyPolicy(...); // HTTP GET handler: correct.
```

## Static Helpers

- Do not add static helper or factory methods in project-owned PHP code by default.
- Static methods hinder testability and should earn their place; tolerate them mainly for third-party APIs, established PHP conventions, or existing framework contracts.
- For simple value objects, prefer direct construction over static factories that only fill one obvious field or wrap a constructor without adding a meaningful invariant.
- If construction logic becomes non-trivial, prefer an injectable factory or collaborator over a project-owned static helper.

## Refactoring API Cleanup

- After changing a method signature or introducing a richer return type, check production call sites before keeping old compatibility methods.
- Do not keep production methods that are only called by tests. Tests should follow the production API, not preserve dead API surface.
- Avoid paired public methods for the same operation, such as `create(...)` and `createWith...(...)`, unless both are required by production or an external contract.
- If compatibility is intentionally kept, identify the production or external caller that still needs it.

## Collections And Nullability

- Do not return `?array` when an empty array fully represents "nothing found".
- Array-returning methods should return an empty array for "no items".
- Use `?array` only when absence of the collection itself has a real, named meaning that is different from an empty collection.
- Do not use `null` to smuggle failure through collection-producing code. If failure is real and expected, model it explicitly; if it is unexpected, let the exception point to the real defect.

## Tests And Production Code

Do not add production code only to make tests easier. Avoid test-only constructors, fallbacks, flags, or branches; tests should construct collaborators explicitly or use proper mocking and injection.

## Required Pre-Final Self-Review

Before finalizing PHP code changes:

- For a non-trivial implementation or refactor, also use `php-solid-review` to review the resulting diff against only the engineering principles that materially apply. Fix meaningful findings before finalizing; do not enumerate principles that have no finding.
- Review every new or renamed injected dependency and use the complete declared short type in lower camel case.
- Review new or refactored REST endpoints for plural domain resource paths, resource-named controllers, HTTP/route-aligned handler names, and operation/resource-named request DTOs. Prefer separate request and response DTOs; verify any shared DTO is intentional. Do not carry traditional form `Values` naming into a REST API.
- Review every newly added or renamed method.
- Classify each as accessor/property, boolean predicate, action/operation, or factory/construction helper.
- Accessors may use noun names. Predicates should use `is`, `has`, `can`, `should`, or similar.
- Action, operation, formatting, mapping, and helper methods must use verb phrases.
- Remove helper methods that only hide one obvious call unless they enforce a real invariant or improve a repeated concept.
- Check any new defensive branch against known domain/API assumptions. If the user or project states the value cannot occur, do not add handling for it without asking.
- Trace changed input paths and remove downstream field revalidation within the requested scope. Verify input DTO attributes run in middleware, and regex-based fields have one regex, preferably shared with HTML5 `pattern`.
