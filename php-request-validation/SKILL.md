---
name: php-request-validation
description: Applies PHP HTTP request-validation conventions for DTO hydration, Symfony Validator attributes, PSR-15 middleware, RFC 9457 Problem Details, and JavaScript-managed form submissions. Use when adding, changing, or reviewing those boundaries and submission flows.
---

# PHP Request Validation

## Scope And Defaults

Apply these defaults to the requested validation work. Inspect the PHP version, framework, dependency injection, body parsers, DTOs, error handlers, and form submission flow first. Reuse established infrastructure and do not migrate unrelated endpoints or replace an existing validation library solely to apply this skill.

- Prefer Symfony Validator with PHP attributes when selecting a validation library.
- In Slim or another PSR-15 application, validate through explicitly registered route middleware before the controller executes business operations.
- Default browser forms to JavaScript-managed submissions: submit without navigating away, preserve the inputs, and display server errors from Problem Details.
- Support ordinary HTML submissions with controller-rendered errors only when the project or task explicitly requires that flow. Do not add a fallback as an unsolicited requirement.
- Keep HTTP input validation at the web boundary. Domain and application invariants must hold independently for CLI, background jobs, and other callers.

## Request DTOs And Hydration

- Define the accepted request shape, including required and optional fields, nullability, allowed types, nested objects, collections, and unknown-field handling.
- Distinguish an absent field from an explicitly supplied `null`. Use presence checks that preserve that distinction; do not invent defaults for required input.
- Check raw types before constructing a strictly typed DTO. Do not rely on PHP scalar coercion or casts to turn invalid input into valid input.
- Normalize only as the contract allows. HTML form fields usually arrive as strings; a JSON endpoint can require native JSON types. The browser's JSON conversion must follow the same contract.
- Hydrate nested DTOs and collection elements explicitly before cascading validation. Preserve source field names and collection indexes for error locations.
- Use purpose-named immutable request DTOs, reusing existing names such as `<FormName>Values` where established. Constructor promotion needs PHP 8.0, readonly properties need PHP 8.1, and readonly classes need PHP 8.2.
- Handle expected missing-field, type, and hydration failures as contract violations. Do not catch every `Throwable` or classify unrelated `TypeError`, configuration failures, and programming errors as client mistakes.
- Keep hydration, constraint validation, and HTTP serialization as distinct responsibilities. Separate classes only when they improve the existing composition; do not build a generic reflection mapper or registry without a concrete need.

## Symfony Validator

- In a standalone component setup, configure the shared validator with `Validation::createValidatorBuilder()->enableAttributeMapping()->getValidator()` through dependency injection. Attributes must actually be loaded.
- Put declarative constraints on web request DTO properties. Prefer built-in constraints and introduce custom constraints only for rules they cannot express clearly.
- For email fields, explicitly use `#[Assert\Email(mode: Assert\Email::VALIDATION_MODE_HTML5_ALLOW_NO_TLD)]` (`html5-allow-no-tld`) so backend email syntax matches native `<input type="email">` validation. Symfony's default `html5` mode additionally requires a TLD and therefore differs from native HTML validation.
- Use `NotBlank` or `NotNull` according to the contract. Format constraints do not necessarily make a field required, and `NotNull` on an already constructed non-nullable property does not validate missing raw input.
- Use `#[Assert\Valid]` for nested DTOs and object collections after hydration. Cascading constraints do not create nested objects or establish collection element types.
- Keep HTTP-specific constraints and Symfony violation objects out of domain models and application commands. Translate validated web input into application-owned input at the boundary.
- Apply `php-application-security` to external-input and regex safety.

## PSR-15 Middleware

- Select each route's DTO explicitly through route-specific middleware or existing route configuration. Avoid guessing from URL strings or introducing global mutable state.
- Run body parsing before validation and arrange error handling so parsing and validation failures use the established HTTP error infrastructure. Check the framework's actual middleware execution order.
- Distinguish malformed JSON from valid JSON with the wrong shape. Slim 4's default JSON parser can return `null` for both malformed JSON and valid scalar JSON; `getParsedBody()` alone is insufficient. Reuse or configure a parser that reports syntax failures explicitly.
- Preserve JSON object-versus-array shape before associative conversion, including nested input. Associative decoding turns both `{}` and `[]` into `[]`, and an object with numeric keys can look like a PHP list. Do not use `array_is_list()` alone to infer the original JSON shape; retain decoded objects or explicit shape metadata until the contract checks that distinction.
- Reject contract violations with HTTP 422 Problem Details without calling the next handler. The controller and business operations must not run on that branch.
- On success, attach the validated DTO as a class-keyed PSR-7 request attribute and pass the returned request to the next handler.
- Controllers consume the typed attribute and invoke application code; they do not hydrate or manually validate the submission. A missing or wrongly typed required attribute is a route-wiring error, reported with `LogicException`.
- Keep authentication, authorization, and existing CSRF protection in their established middleware. Changing submissions to JSON does not remove those protections.

For an explicitly required ordinary HTML submission, middleware may attach values and a validation result on either outcome so the controller can render errors with preserved values. The controller must call application operations only on success. This exception does not apply to the default JavaScript-managed flow.

## Problem Details

For parsing and contract failures, read [references/problem-details.md](references/problem-details.md) for the response contract, status mapping, and error-location rules.

Centralize serialization through the existing error infrastructure or one focused response collaborator. Return safe public messages and application-owned codes, with `application/problem+json`; do not expose submitted secrets, framework exception text, or stack traces.

## Browser Forms

- Prefer native HTML validation attributes and appropriate input types. Use JavaScript for submission and feedback, adding custom client validation only where necessary.
- Submit with `fetch` or the project's existing lightweight mechanism. JSON and form data are both possible; choose the endpoint's declared media type and types. No large frontend validation framework is required.
- Keep entered values on validation, network, and other submission failures. Reset or navigate only after confirmed success, according to the success contract.
- Handle non-success HTTP responses explicitly; `fetch` does not treat HTTP 422 as a network rejection. Map Problem Details locations to known form controls, and show an accessible error summary for unmapped or form-level errors.
- Render public error text safely, without treating it as HTML. Clear stale feedback when corrected or resubmitted so old errors do not prevent valid submissions.
- Browser checks are usability aids. Always validate on the server; server-backed checks remain appropriate for rules that the browser cannot decide.

## Verification

Follow `php-testing-style` and test the affected boundaries. Use focused tests for hydration, constraints, error mapping, and serialization, supplemented by pipeline integration tests using the real parser and validator metadata.

Cover applicable valid input, missing/null/type failures, malformed JSON versus valid wrong-shaped JSON, nested and collection constraints, multiple errors, correct pointers and content type, middleware short-circuiting, and delivery of the typed DTO. For changed browser submissions, verify that a 422 response preserves inputs and renders errors, and that failed requests do not trigger the success flow.

Reuse existing domain-invariant coverage unless the invariant or its integration changed. Run relevant tests, static analysis, and coding-standard checks available in the application, and report any deliberate departures from these defaults.
