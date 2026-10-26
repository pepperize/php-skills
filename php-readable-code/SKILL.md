---
name: php-readable-code
description: Use when writing, refactoring, or reviewing PHP production code around readability, responsibilities, naming, repository read/write naming, REST resource/service/DTO naming and creation responses, server-rendered page and HTML form distinctions, guard clauses, factories, utilities, nullable collections, or test-only production code.
---

# PHP Readable Code

## Default Style

- Prefer small focused classes, explicit responsibilities, intention-revealing names, readable control flow, and minimal incidental complexity.
- Prefer GoF design patterns where they fit naturally.
- Avoid broad utility classes that mix unrelated concerns such as creation, mapping, conversion, logging, and key formatting; extract cohesive collaborators with narrow names instead.
- Avoid passing non-trivial method calls directly as arguments when an intermediate variable would clarify intent. Name semantically important intermediate results.
- Prefer simple, common words that non-native speakers can read without looking them up.

## Orchestration And Local Operations

Keep orchestration methods at one level of abstraction: the caller should reveal the sequence of meaningful operations without coordinating their field checks, branching and construction details. Extract a complete operation into a purpose-named method, such as `createRequestDto(...)`, rather than wrapping individual expressions in predicates that leave the caller doing the same detailed work.

Prefer a private method when the operation belongs to one owner. Introduce a separate collaborator when its independent responsibility, actual reuse, complexity or composition benefits justify that boundary. Returning an object does not by itself require a factory class. Keep ordinary expressions inline when extracting them would add indirection without clarifying the operation.

For input-boundary construction and failure handling, follow `php-request-validation` and `php-logging-exceptions`; local extraction must preserve the accepted input and error contracts.

## Imports And Aliases

- Import classes using their full namespace and refer to their actual short names.
- Do not rename classes or alias namespaces for brevity, convenience, or framework convention. Avoid mappings such as `Constraints as Assert` and `Mapping as ORM`.
- When short names collide, prefer fully qualified class references at the affected usages.
- Aliasing is a last resort for actual collisions where fully qualified references materially reduce readability. Use aliases sparingly and derive their names from the original namespace.
- During self-review, remove every alias that does not meet these conditions.

## Backend Resource Flow

For standard resource operations, follow Controller -> Service -> Repository and the DTO/entity boundaries in [API Responsibilities](../php-api-endpoints/SKILL.md#responsibilities). Read its [worked flow](../php-api-endpoints/references/user-endpoint.md#flow-and-naming) when implementing or refactoring these collaborators.

Name the roles Controller, Service, Repository, and Factory. Another suffix needs a concrete different responsibility, such as middleware, validation, rendering, or technical client communication. Classify the primary responsibility before naming; use [Factories](#factories) for product construction. Preserve explicit project contracts and established ViewService/Renderer names for rendered pages.

Entities, DTOs, and other data carriers retain their own names. A repository implementation may identify its mechanism while retaining the Repository suffix, such as `DoctrineUserRepository`.

## Dependency Names

Name each injected dependency after its declared short type, dropping a trailing `Interface` before converting it to lower camel case. Apply the same name to the constructor parameter and property. Preserve other role suffixes such as `Repository`, `Factory`, `Generator`, `Service`, and `Client`; they distinguish the collaborator from the values it returns. Keep declared type names unchanged.

```php
private MailerInterface $mailer;
private LoggerInterface $logger;
private RouteParserInterface $routeParser;
private EntityManagerInterface $entityManager;
private UserRepositoryInterface $userRepository;
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
    $this->siteHeaderViewModelFactory->createForLegalPage($locale, 'privacy-policy'),
    $this->fetchContent(),
    $this->legalNavigationViewModelFactory->create($locale, 'privacy-policy'),
);
```

Keep each meaningful intermediate result visible:

```php
$metadata = new PageMetadataViewModel($locale, 'Privacy policy');
$header = $this->siteHeaderViewModelFactory->createForLegalPage($locale, 'privacy-policy');
$content = $this->fetchContent();
$legalNavigation = $this->legalNavigationViewModelFactory->create($locale, 'privacy-policy');

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

## Validation Placement

Validate external input once at its entry boundary; keep state-dependent business decisions with their owning operation. [Validation Ownership](../php-request-validation/SKILL.md#validation-ownership) owns that distinction, DTO constraints, other entry points, and the prohibition on downstream field revalidation.

For regex-based fields, follow [One Regex Per Field](../php-request-validation/SKILL.md#one-regex-per-field). Preserve accepted values and apply [contextual output handling](../php-application-security/SKILL.md#output-handling) at output.

## Factories

Before choosing a class name, identify its primary responsibility. When that responsibility is constructing and returning an object or object graph, name the class after its product plus `Factory` and name the main method `create(...)`.

This names a justified collaborator; it does not require a new class for every construction operation. Use the local-operation guidance above when construction belongs in a private method.

Reflection, cloning, metadata interpretation and nested construction are implementation details; they do not justify using `Generator` for an object factory. For example, a collaborator that derives a Symfony `Collection` from DTO metadata is a `DtoConstraintsFactory::create(...)`.

Returning an object alone does not make a class a factory: retrieval, validation and other operations retain their own roles. Preserve explicit user/project naming requirements and framework-required contracts.

For shared presentation factories, a purpose-revealing `createFor...(...)` operation may distinguish a real creation variant, such as `SiteHeaderViewModelFactory::createForLegalPage(...)`.

## Repository Method Naming

Use these names for supported repository operations, regardless of the storage implementation:

| Operation | Method names |
| --- | --- |
| Find one object by identifier, or read a singular source | `find(...)` |
| Read the complete collection | `findAll()` |
| Find multiple objects by criteria | `findBy(...)` |
| Find one object by criteria | `findOneBy(...)` |
| Save one or multiple objects | `save(...)`, `saveAll(...)` |
| Delete one object or an object by identifier | `delete(...)`, `deleteById(...)` |
| Delete all objects, a supplied collection, or supplied identifiers | `deleteAll(...)`, `deleteAllById(...)` |
| Flush pending changes | `flush()` |
| Save one or multiple objects and immediately flush | `saveAndFlush(...)`, `saveAllAndFlush(...)` |

- Expose only operations required by callers. These names do not require a generic base repository or unused CRUD methods.
- Use these names instead of aliases such as `tryAdd`, `add`, `insert`, `update`, `persist`, or `remove` for the corresponding repository operations.
- Match the name to the persistence contract. The `AndFlush` variants flush pending changes as part of the operation; use them when immediate flushing is part of the contract.

## REST API Naming

- For REST resource implementation or refactoring, apply `php-api-endpoints` and read its [worked User endpoint](../php-api-endpoints/references/user-endpoint.md) before editing. It owns the controller/service/DTO/repository implementation pattern.
- Select naming by [Endpoint Contracts](../php-api-endpoints/SKILL.md#endpoint-contracts); a rendered form calling a REST endpoint still uses REST names. Read [HTTP endpoint examples](references/http-endpoint-examples.md) before designing or refactoring these boundaries.
- For new or intentionally redesigned REST endpoints, name resource collections with plural nouns from the domain language. Let the HTTP method express the operation: `POST /api/users` creates a user; `GET /api/users/{userId}` reads a user.
- Choose the resource actually created or addressed. Do not name a user-creation endpoint after its registration form, controller, or workflow. Use `/api/registrations` only when a registration is itself a domain resource with its own identity and lifecycle.
- Name REST controllers after the addressed domain resource: `UserController` handles `/api/users`. Controller methods mirror the HTTP verb and route resource, such as `postUsers()` and `getUsers()`. Do not name a REST controller after the registration form or workflow.
- Name REST request DTOs after the operation and resource with a `Request` suffix: `CreateUserRequest` is the body of `POST /api/users`. Reserve names such as `RegistrationValues` or `UserCreationValues` for traditional form data. A browser form calling a REST API still uses REST request naming.
- Name REST validation middleware after the request DTO, such as `CreateUserRequestValidationMiddleware`; use `<FormName>ValidationMiddleware` for traditional form actions.
- Name independent input/output contracts CreateUserRequest and output-only UserDto under [API Responsibilities](../php-api-endpoints/SKILL.md#responsibilities). UserDto does not imply shared request/response use. Preserve explicit project output names such as UserResponse or CreateUserResponse; DTOs remain distinct from the User entity.
- For REST resource operations, keep the resource name across the controller, application service, and DTOs: `UserController`, `UserService`, `CreateUserRequest`, and `UserDto`. Use `create`, `read`, `update`, and `delete` for supported CRUD operations; `UserService::create()` creates a User. Do not introduce workflow synonyms such as `RegistrationService::register()` for the same REST resource operation. Add only operations callers need; CRUD naming does not require a generic base service or unused methods.
- For server-rendered pages, use page ViewServices and Renderers. For traditional HTML form actions, capability names such as `RegistrationService::register()` remain appropriate. Apply the existing submission-flow rules in `php-request-validation`; do not impose REST CRUD names or resource-creation responses on these endpoints. Frontend UI capabilities may also retain workflow names.
- Treat a request to refactor a REST endpoint according to this skill as including corrections to its route, controller, application-service, and DTO names. Preserve explicitly required compatibility and unrelated API behavior; do not silently exclude naming corrections just because the old names already exist. Update routes, clients, tests, and contract documentation together. Do not add compatibility aliases without a caller or contract that requires them.

For a REST resource operation that creates a `User`:

| Good | Bad | Reason |
| --- | --- | --- |
| `POST /api/users` | `POST /api/registration` | The collection names the created domain resource rather than the workflow. |
| `POST /api/users` | `POST /api/registerUser` | The HTTP method expresses the operation rather than an action in the path. |
| `GET /api/users/{userId}` | `GET /api/user/{userId}` | A member remains addressed under the plural resource collection. |
| `UserController::postUsers()` | `RegistrationController::postRegistration()` | The controller names the resource and the handler mirrors the HTTP route. |
| `UserService::create()` | `RegistrationService::register()` | The REST resource operation keeps the same User vocabulary through its application service. |
| `CreateUserRequest` | `RegistrationValues`, `UserCreationValues` | A REST request body names the operation and resource rather than form values. |
| Separate `CreateUserRequest` and output-only `UserDto` | Automatically sharing an input/output DTO | Input and output contracts can evolve independently. |

## REST Resource Creation Responses

Completed REST resource creation requires 201, the canonical member Location, and a public representation from the persisted entity. [API HTTP Response Contract](../php-api-endpoints/SKILL.md#http-response-contract) owns the complete rule, lifecycle and asynchronous distinctions, secret exclusion, and compatibility exceptions. Keep the controller's DTO-to-response delegation visible during review.

Traditional HTML actions follow [Traditional HTML Submissions](../php-request-validation/SKILL.md#traditional-html-submissions).

## Method Names

- Methods should read as actions. Prefer verb phrases such as `createMissingTranslationSkip`, `collectRoutes`, `resolveCountryCode`, or `publishSeoData`.
- Do not repeat information already carried by the class name, receiver, or return type unless it distinguishes variants or avoids ambiguity at call sites. Prefer `DataFactory::create()` over `DataFactory::createData()`.
- Avoid noun/adjective-only method names like `missingTranslation(...)` unless the method is an accessor, enum/value property, or boolean predicate.
- Boolean predicates should still read clearly as questions or states, using `is`, `has`, `can`, `should`, or similar.
- Static factory methods should also use an action-oriented name unless they follow an established PHP or project convention such as `from(...)`.
- Before accepting new or renamed methods, classify each one as an accessor/property, boolean predicate, action/operation, or factory/construction helper. Accessors should use noun or state names such as `status()`, `totalCount()`, `successCount()`, or `failureCount()`. Boolean predicates should read as predicates, such as `isSuccess()` or `hasFailures()`. Action, operation, and factory helper methods must use verb phrases. Avoid past-tense or adjective helper names such as `succeeded(...)`, `failed(...)`, `missingTranslation(...)`, or `partialSuccess(...)` when the method creates, transforms, or returns a result; prefer names such as `createSuccessResult(...)`, `createFailureResult(...)`, `resolveStatus()`, or `collectFailures(...)`.

### Fetching Data

- For REST resource services, keep the CRUD name `read(...)` even when it performs repository I/O. This scoped naming rule takes precedence over `fetch...` guidance. Repository contracts use the read names defined under Repository Method Naming.
- Outside REST resource services, use `fetch...` for query operations that perform repository, filesystem, network, or other potentially costly I/O. Do not name these operations `get...`, because `get` suggests a cheap accessor.
- Prefer a purpose-revealing name such as `fetchViewData()` over a generic `fetch()`.
- Name a page-level ViewService query that performs I/O `fetchPage(...)`.
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

- Review the complete task change set, including task-created untracked PHP files, using git status and staged/unstaged diffs.
- For every new or renamed class, or class whose responsibility changed, infer its primary responsibility and returned product from its implementation. Apply the naming rules above and correct affected callers, tests, and documentation. Briefly report the role, product, and naming decision for newly introduced collaborators.
- Check every import alias against [Imports And Aliases](#imports-and-aliases) and every injected dependency against [Dependency Names](#dependency-names).
- Trace resource operations through the [API responsibility boundaries](../php-api-endpoints/SKILL.md#responsibilities); explain concrete departures.
- Identify each endpoint contract, then check [REST API Naming](#rest-api-naming) and the [HTTP response contract](../php-api-endpoints/SKILL.md#http-response-contract). Keep rendered-page and HTML-action contracts distinct.
- Classify every new or renamed method as an accessor, predicate, action, or construction helper under [Method Names](#method-names).
- Review changed orchestration and helpers under [Orchestration And Local Operations](#orchestration-and-local-operations); remove wrappers that hide an obvious call without a real benefit.
- Check input paths against [Validation Ownership](../php-request-validation/SKILL.md#validation-ownership) and regex fields against [One Regex Per Field](../php-request-validation/SKILL.md#one-regex-per-field).
- Check defensive branches against actual domain/API states; ask before handling a value the user or project says cannot occur.
- Apply [PHP Design Review](../php-solid-review/SKILL.md#implementation-self-review) to non-trivial implementations and refactors, fixing material findings within scope.
