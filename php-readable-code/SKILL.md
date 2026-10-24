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

For standard backend resource operations, start with `Controller -> Service -> Repository`, with an optional technical `Client` behind the repository. Derive collaborator names from their responsibilities in this flow:

- Controllers adapt HTTP input, call services and complete HTTP responses.
- Services accept application input DTOs, coordinate the operation and return output DTOs for resource results.
- Repositories accept entities for persistence and return entities for entity results. Lookups may take identifiers or criteria; request and response DTOs do not cross this boundary.
- Factories construct entities from input DTOs and output DTOs from entities. Services coordinate these factories around repository calls.

Use the corresponding `Controller`, `Service`, `Repository` and `Factory` suffixes. DTO-to-entity and entity-to-DTO construction use `<Product>Factory::create(...)`, rather than a new role name for the same work. A repository implementation may identify its mechanism, such as `DoctrineUserRepository`, while retaining its repository role.

Choose another collaborator suffix only for a concrete different responsibility, such as middleware, validation, rendering or technical client communication. DTOs, entities and other data carriers retain their own names. Preserve explicit project contracts and the established ViewService/Renderer patterns for server-rendered pages.

Read the [worked resource flow and naming examples](../php-api-endpoints/references/user-endpoint.md#flow-and-naming) when implementing or refactoring these collaborators. Classify the architectural role before choosing the name; returning an object alone does not distinguish a service, repository or factory.

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

Before choosing a class name, identify its primary responsibility. When that responsibility is constructing and returning an object or object graph, name the class after its product plus `Factory` and name the main method `create(...)`.

This names a justified collaborator; it does not require a new class for every construction operation. Use the local-operation guidance above when construction belongs in a private method.

Reflection, cloning, metadata interpretation and nested construction are implementation details; they do not justify using `Generator` for an object factory. For example, a collaborator that derives a Symfony `Collection` from DTO metadata is a `DtoConstraintsFactory::create(...)`.

Returning an object alone does not make a class a factory: retrieval, validation and other operations retain their own roles. Preserve explicit user/project naming requirements and framework-required contracts.

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
- Select conventions by the endpoint's contract. REST resource endpoints, server-rendered page endpoints, and traditional HTML form actions have different naming and response contracts. Neither the HTTP method nor the fact that a browser form exists selects the contract. A server-rendered form submitting to a REST resource endpoint follows REST rules. Read [HTTP endpoint examples](references/http-endpoint-examples.md) before designing or refactoring these boundaries.
- For new or intentionally redesigned REST endpoints, name resource collections with plural nouns from the domain language. Let the HTTP method express the operation: `POST /api/users` creates a user; `GET /api/users/{userId}` reads a user.
- Choose the resource actually created or addressed. Do not name a user-creation endpoint after its registration form, controller, or workflow. Use `/api/registrations` only when a registration is itself a domain resource with its own identity and lifecycle.
- Name REST controllers after the addressed domain resource: `UserController` handles `/api/users`. Controller methods mirror the HTTP verb and route resource, such as `postUsers()` and `getUsers()`. Do not name a REST controller after the registration form or workflow.
- Name REST request DTOs after the operation and resource with a `Request` suffix: `CreateUserRequest` is the body of `POST /api/users`. Reserve names such as `RegistrationValues` or `UserCreationValues` for traditional form data. A browser form calling a REST API still uses REST request naming.
- Prefer separate input and output DTOs so accepted input and returned output have independent contracts. Use `CreateUserRequest` for input and output-only `UserDto` for the public resource representation. `UserDto` does not imply shared request/response use. Preserve explicit project response names such as `UserResponse` or `CreateUserResponse` when required. DTOs remain distinct from the domain entity `User`.
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

- For a REST POST that completes resource creation, require all three: `201 Created`, a `Location` header identifying the created resource's canonical member URL, and a response body representing that resource, including its identifier and server-assigned public values. These are this skill collection's conventions; do not describe the mandatory body as an HTTP-standard requirement.
- The resource service's `create()` accepts the same validated input DTO, coordinates creation and persistence, maps the persisted domain entity through a focused DTO factory, and returns the public resource DTO, such as `UserDto`. The controller passes that DTO to the established response factory or responder; it does not map domain entities. Keep PSR-7 request/response objects, status selection, URL generation, and JSON serialization out of the resource service. The response collaborator generates the member URL and completes the HTTP response.
- Explicitly select response fields. Never serialize a domain entity wholesale or serialize the submitted input as the response; omit passwords, hashes, bearer tokens, and other secrets. Use the project's existing serializer/responder and response-mapping convention rather than inventing one for the example.
- Pending verification or another lifecycle state does not make completed resource creation asynchronous. Use `202 Accepted` only for an explicitly asynchronous contract whose processing has not completed. POST actions that do not create a resource and explicitly required existing compatibility contracts retain their own documented responses; flag a conflict with these defaults instead of silently treating it as the normal creation shape.
- For a traditional HTML form action, retain the HTML contract: render invalid submissions with preserved safe values and the appropriate status, and ordinarily redirect after success with `303 See Other` (Post/Redirect/Get). A server-rendered GET returns HTML from its page ViewModel and renderer. Neither flow requires a JSON resource body or `201` creation response.

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

- Determine the task's review set with `git status --short` and staged/unstaged diffs. Read task-created untracked PHP files explicitly; `git diff` alone omits them.
- For every new or renamed class, or class whose responsibility changed, identify its primary responsibility and returned product, if any, from its implementation. Verify the class and main method against the applicable naming rule; fix mismatches in affected dependencies, callers, tests and documentation.
- For standard resource operations, trace controller DTO input through the service, entity factory, entity repository and output DTO factory. Verify the role suffixes and explain any concrete departure from this flow.
- Briefly report the role, product and naming decision for newly introduced collaborators.
- For a non-trivial implementation or refactor, also use `php-solid-review` to review the resulting diff against only the engineering principles that materially apply. Fix meaningful findings before finalizing; do not enumerate principles that have no finding.
- Review every new or renamed injected dependency and use the complete declared short type in lower camel case.
- Identify each changed endpoint's contract before reviewing naming and responses. For REST resource endpoints, verify plural domain resource paths, resource-named controllers and application services, CRUD service operations, HTTP/route-aligned handlers, and operation/resource-named request DTOs. Prefer separate request and response DTOs; verify any shared DTO is intentional. Do not carry traditional form `Values` naming into a REST API or force REST naming onto an HTML workflow.
- For a completed REST resource-creation POST, verify `create()` returns the public DTO mapped from the persisted entity, the controller delegates that DTO to the response collaborator, and the response has `201`, the correct member `Location`, and a body containing its identifier without secrets. For server-rendered pages and traditional HTML form actions, verify their HTML rendering/error/redirect contract instead.
- Review every newly added or renamed method.
- Classify each as accessor/property, boolean predicate, action/operation, or factory/construction helper.
- Accessors may use noun names. Predicates should use `is`, `has`, `can`, `should`, or similar.
- Action, operation, formatting, mapping, and helper methods must use verb phrases.
- Remove helper methods that only hide one obvious call unless they enforce a real invariant or improve a repeated concept.
- Read each changed orchestration method as a sequence of meaningful operations. Extract cohesive details at the operation boundary; do not replace them with many tiny wrappers or require another class without a concrete benefit.
- Check any new defensive branch against known domain/API assumptions. If the user or project states the value cannot occur, do not add handling for it without asking.
- Trace changed input paths and remove downstream field revalidation within the requested scope. Verify input DTO attributes run in middleware, and regex-based fields have one regex, preferably shared with HTML5 `pattern`.
