---
name: php-readable-code
description: Use when writing, refactoring, or reviewing PHP production code around readability, responsibilities, naming, guard clauses, factories, utilities, nullable collections, or test-only production code.
---

# PHP Readable Code

## Default Style

- Prefer small focused classes, explicit responsibilities, intention-revealing names, readable control flow, and minimal incidental complexity.
- Prefer GoF design patterns where they fit naturally.
- Avoid broad utility classes that mix unrelated concerns such as creation, mapping, conversion, logging, and key formatting; extract cohesive collaborators with narrow names instead.
- Avoid passing non-trivial method calls directly as arguments when an intermediate variable would clarify intent. Name semantically important intermediate results.
- Prefer simple, common words that non-native speakers can read without looking them up.

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

At API boundaries, prefer the project's established boundary validation mechanism for request-shape constraints such as nullness, blank strings, size, simple patterns, enum values, nested DTO validation, and other request binding concerns.

Do not introduce predicate or specification classes merely to wrap simple boundary validation rules, one-off null/blank/range checks, or controller-specific request syntax.

Consider a named predicate, specification, policy, or validator only when the validation is non-trivial and at least one of these is true:

- The rule must be applied outside the controller/API boundary, such as generated data, persisted data, infrastructure keys, filenames, external-system data, or reused application flows.
- The rule is not readable or maintainable in the established boundary validation mechanism alone.
- The rule has a stable domain or technical name that makes the caller clearer.
- The rule is security-sensitive and benefits from isolated focused tests.

Keep predicate and specification classes side-effect free. They should answer the validation question and leave exception choice, HTTP mapping, logging, and recovery decisions to the caller that owns that boundary.

## Factories

When a class mainly creates a returned object, prefer the Factory pattern: name the class after the product plus `Factory`, and name the main method `create(...)`.

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

- Review every newly added or renamed method.
- Classify each as accessor/property, boolean predicate, action/operation, or factory/construction helper.
- Accessors may use noun names. Predicates should use `is`, `has`, `can`, `should`, or similar.
- Action, operation, formatting, mapping, and helper methods must use verb phrases.
- Remove helper methods that only hide one obvious call unless they enforce a real invariant or improve a repeated concept.
- Check any new defensive branch against known domain/API assumptions. If the user or project states the value cannot occur, do not add handling for it without asking.
