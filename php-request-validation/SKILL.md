---
name: php-request-validation
description: Applies PHP HTTP request-validation conventions for DTO hydration, Symfony Validator attributes, PSR-15 middleware, typed controller argument resolution in Slim, RFC 9457 Problem Details, and JavaScript-managed form submissions. Use when adding, changing, or reviewing those input boundaries, controller DTO bindings, and submission flows.
---

# PHP Request Validation

## Scope And Defaults

Apply these defaults to the requested validation work. Inspect the PHP version, framework, dependency injection, body parsers, DTOs, error handlers, and form submission flow first. Reuse established infrastructure and do not migrate unrelated endpoints or replace an existing validation library solely to apply this skill.

For REST resource implementation, apply `php-api-endpoints` and read its [worked User endpoint](../php-api-endpoints/references/user-endpoint.md). It shows how the validated input connects to the controller, DTO-returning service and persistence adapter; validation mechanics remain owned by this skill. When following that reference, preserve its hydration-result factory, request validator and typed error values, with middleware coordinating them and the response collaborator owning HTTP error mapping. Do not collapse that split merely to shorten a two-field example; preserve explicit project normalization, unknown-field and parser/protection contracts.

Identify the submission endpoint's contract separately from how the initial page was rendered. Apply `php-readable-code` and its HTTP endpoint examples for REST resource/service naming and creation responses versus server-rendered pages and traditional HTML form actions. A form calling a REST resource endpoint uses its REST contract; an explicitly required ordinary HTML POST retains its page/workflow vocabulary and HTML errors/redirects. JavaScript-managed submission alone does not turn a capability endpoint into a REST resource endpoint.

- Prefer Symfony Validator with PHP attributes when selecting a validation library.
- In typical PHP HTTP applications, declare input constraints as Symfony Validator attributes on the input DTO and execute them in explicitly registered route middleware before the controller or service runs. In Slim or another PSR-15 application, use PSR-15 middleware; otherwise use the framework's input-layer equivalent.
- Default browser forms to JavaScript-managed submissions: validate locally before submission, submit without navigating away, preserve the inputs, and display frontend-owned messages with frontend-owned localization.
- Support ordinary HTML submissions with controller-rendered errors only when the project or task explicitly requires that flow. Do not add a fallback as an unsolicited requirement.
- Within the backend, validate external input only in the input layer. Controllers consume validated DTOs; services, application commands, domain objects, repositories, and output renderers must not repeat field validation or add a second validation pass. This restriction does not prohibit independent browser validation.
- Required values, types, nullability, lengths, formats, character composition, allowed values, and cross-field input constraints belong to that input layer. Calling an email or password format rule a domain invariant does not justify validating it again in a service.
- CLI commands, imports, jobs, and external-system adapters validate their external input at their own entry boundary before invoking the same services. Do not add service checks for hypothetical callers.
- Business decisions requiring current application state, such as permissions, ownership, uniqueness, or allowed lifecycle transitions, remain in their owning application/domain operation. They are not a second pass over input syntax.
- Validate at input and escape or encode at the actual output context. Never pre-escape DTO or stored values, and never use successful validation as a reason to omit output escaping.

## Request DTOs And Hydration

- Define the accepted request shape, including required and optional fields, nullability, allowed types, nested objects, collections, and unknown-field handling.
- Distinguish an absent field from an explicitly supplied `null`. Use presence checks that preserve that distinction; do not invent defaults for required input.
- Check raw types before constructing a strictly typed DTO. Do not rely on PHP scalar coercion or casts to turn invalid input into valid input.
- Hydrate and perform permitted normalization once at the input boundary. Services must not repeat normalization. HTML form fields usually arrive as strings; a JSON endpoint can require native JSON types. The browser's JSON conversion must follow the same contract.
- Hydrate nested DTOs and collection elements explicitly before cascading validation. Preserve source field names and collection indexes for error locations.
- Shape immutable input DTOs around the application operation. By default, use the same application-owned DTO for HTTP input and as the application service parameter. For REST APIs, follow `php-readable-code`: use operation/resource names such as `CreateUserRequest` for `POST /api/users` and prefer separate request and response DTOs. A browser form submitting to a REST API follows the same naming. Reserve `<FormName>Values` for traditional form endpoints; an existing form-style DTO name does not override a requested REST naming refactor.
- Introduce a separate service input type and mapping only when an actual difference in contracts requires it. Different architectural roles, class names, or hypothetical future callers alone do not justify copying the validated DTO into another object.
- Constructor promotion needs PHP 8.0, readonly properties need PHP 8.1, and readonly classes need PHP 8.2.
- Handle expected missing-field, type, and hydration failures as contract violations. Do not catch every `Throwable` or classify unrelated `TypeError`, configuration failures, and programming errors as client mistakes.
- Keep hydration, constraint validation, and HTTP serialization as distinct responsibilities. Separate classes only when they improve the existing composition; do not build a generic reflection mapper or registry without a concrete need.

## Symfony Validator

- In a standalone component setup, configure the shared validator with `Validation::createValidatorBuilder()->enableAttributeMapping()->getValidator()` through dependency injection. Attributes must actually be loaded.
- Put declarative constraints on web request DTO properties. Prefer built-in constraints and introduce custom constraints only for rules they cannot express clearly.
- For email fields, explicitly use `#[Assert\Email(mode: Assert\Email::VALIDATION_MODE_HTML5_ALLOW_NO_TLD)]` (`html5-allow-no-tld`) so backend email syntax matches native `<input type="email">` validation. Symfony's default `html5` mode additionally requires a TLD and therefore differs from native HTML validation.
- Use `NotBlank` or `NotNull` according to the contract. Format constraints do not necessarily make a field required, and `NotNull` on an already constructed non-nullable property does not validate missing raw input.
- Use `#[Assert\Valid]` for nested DTOs and object collections after hydration. Cascading constraints do not create nested objects or establish collection element types.
- Symfony constraint attributes are permitted metadata on shared application input DTOs. Hydration, validator execution, violation handling, and HTTP error serialization remain input-boundary concerns. Keep constraint attributes out of domain models; services do not receive PSR-7 requests or Symfony violation objects.
- Apply `php-application-security` to external-input and regex safety.

## One Regex Per Field

- When a field needs regex validation, use one full-value regex in one `Assert\Regex` attribute. Combine the field's character requirements into that expression; do not stack separate regex constraints for uppercase, lowercase, digits, symbols, or forbidden characters, or repeat those checks with `preg_match()` elsewhere.
- Keep built-in constraints for presence, length bounds, native email syntax, and other rules they already express. One regex per field does not mean replacing every constraint with regex. Apply a bounded length constraint before a potentially expensive regex.
- Prefer one canonical regex body shared by the backend attribute and the frontend HTML5 `pattern` attribute. Own the pattern in the input contract, not a domain policy. Render it or export it through the existing frontend build/configuration mechanism; do not maintain independently authored PHP and JavaScript copies or create a generic pattern registry.
- Adapt only engine syntax: PHP needs delimiters, appropriate flags, and explicit whole-value anchoring; HTML `pattern` takes the undelimited body, matches the whole value, and uses JavaScript's `v` flag. Use syntax supported by both engines and do not assume PCRE and JavaScript accept every expression identically. See the [HTML pattern specification](https://html.spec.whatwg.org/multipage/input.html#attr-input-pattern).
- If an actual engine or input-type limitation prevents sharing, document the concrete reason and keep one regex per field in each supported engine with the same accepted/rejected behavior. Do not silently weaken either contract. If no safe regex expresses the format, use a built-in constraint or one deterministic validator in the input layer instead of several regexes.
- Use a field-level message that describes the combined requirement. Distinct messages for individual character requirements do not justify multiple regex constraints.

## PSR-15 Middleware

- Select each route's DTO explicitly through route-specific middleware or existing route configuration. Avoid guessing from URL strings or introducing global mutable state.
- Run body parsing before validation and arrange error handling so parsing and validation failures use the established HTTP error infrastructure. Check the framework's actual middleware execution order.
- Distinguish malformed JSON from valid JSON with the wrong shape. Slim 4's default JSON parser can return `null` for both malformed JSON and valid scalar JSON; `getParsedBody()` alone is insufficient. Reuse or configure a parser that reports syntax failures explicitly.
- Preserve JSON object-versus-array shape before associative conversion, including nested input. Associative decoding turns both `{}` and `[]` into `[]`, and an object with numeric keys can look like a PHP list. Do not use `array_is_list()` alone to infer the original JSON shape; retain decoded objects or explicit shape metadata until the contract checks that distinction.
- Reject contract violations with HTTP 422 Problem Details without calling the next handler. The controller and business operations must not run on that branch.
- On success, attach the validated DTO as a class-keyed PSR-7 request attribute and pass the returned request to the next handler.
- Controllers receive the validated DTO and, by default, pass that same instance directly to the application service through a typed parameter. They do not hydrate, normalize, or manually validate the submission. In Slim projects, prefer typed controller parameters resolved by declared type from class-keyed request attributes. Keep `ServerRequestInterface` when the action needs other request data. Report missing or wrongly typed required DTOs as `LogicException` at the invocation boundary, before name-based resolution or container autowiring can supply an alternative value. Other frameworks use their established input-layer equivalent.
- After validated input reaches a REST resource-creation action, call the resource service's `create()`, which returns the public DTO mapped from the persisted entity. Delegate that DTO to the established response collaborator; the controller does not map the domain entity. For completed creation, require `201`, the created member's `Location`, and a representation including its identifier without secrets, following `php-readable-code`. A traditional HTML form action instead renders invalid input or redirects after successful application work; middleware does not choose a REST success response for that HTML flow.
- Keep authentication, authorization, and existing CSRF protection in their established middleware. Changing submissions to JSON does not remove those protections.

For an explicitly required ordinary HTML submission, middleware may attach values and a validation result on either outcome so the controller can render errors with preserved safe values. The controller must call application operations only on success and ordinarily returns a `303` redirect after that work (Post/Redirect/Get). Keep secrets out of rendered values. This exception does not apply to the default JavaScript-managed flow and does not impose REST CRUD naming on traditional HTML actions.

## Slim Controller Arguments

When implementing or changing request DTO delivery to Slim controller parameters, read [references/slim-controller-arguments.md](references/slim-controller-arguments.md). Select required DTO types explicitly, reuse the installed invocation infrastructure, and keep submitted DTOs out of the shared DI container. Apply the convention to affected routes without migrating unrelated endpoints or installing another framework solely for argument binding.

## Problem Details

For parsing and contract failures, read [references/problem-details.md](references/problem-details.md) for the response contract, status mapping, and error-location rules.

Centralize serialization through the existing error infrastructure or one focused response collaborator. Return application-owned codes with `application/problem+json`. Keep any diagnostic text safe; do not expose submitted secrets, framework exception text, or stack traces. Diagnostic text is for API consumers and must not supply browser UI copy. Do not add backend translations of API diagnostics solely to provide browser validation messages.

## Browser Forms

- Validate locally before sending the request. Prefer native HTML validation attributes and appropriate input types; use their constraint state to select frontend-owned messages and localization. Add custom client validation only for rules native constraints cannot express. Routine field errors must not require a server round trip.
- For regex-based field rules, use the shared pattern body as HTML5 `pattern` rather than adding a separate JavaScript validator. Keep `required`, length attributes, and native input types consistent with the DTO contract; explain any concrete difference in Unicode length counting.
- Submit with `fetch` or the project's existing lightweight mechanism. JSON and form data are both possible; choose the endpoint's declared media type and types. No large frontend validation framework is required.
- Keep entered values on validation, network, and other submission failures. Reset or navigate only after confirmed success, according to the success contract.
- Handle non-success HTTP responses explicitly; `fetch` does not treat HTTP 422 as a network rejection. For actionable server rejections, use stable problem types or application codes and documented locations to select frontend-owned feedback. Map relevant locations to known form controls; show an accessible summary with a frontend-owned generic message for unknown, unmapped, or form-level failures.
- Never display response `title`, `detail`, per-error diagnostic text, or raw validator messages in the browser. Do not parse them to decide behavior or use them as fallback UI copy. Render frontend-owned messages safely as text and clear stale feedback when corrected or resubmitted.
- Keep messages and their translations in the existing frontend presentation or localization mechanism. Rules that need server state, such as conflicts or changed legal-document versions, still return server outcomes; the frontend owns the displayed explanation and recovery guidance.
- Browser checks are usability aids. Always validate on the server; server-backed checks remain appropriate for rules that the browser cannot decide.

## Verification

Follow `php-testing-style` and test the affected boundaries. Use focused tests for hydration, constraints, error mapping, and serialization, supplemented by pipeline integration tests using the real parser and validator metadata.

Cover applicable valid input, missing/null/type failures, malformed JSON versus valid wrong-shaped JSON, nested and collection constraints, multiple errors, correct pointers and content type, middleware short-circuiting, and delivery of the typed DTO. For changed browser submissions, verify that locally invalid input prevents the request and shows frontend-owned localized feedback. Verify that a 422 response preserves inputs and selects frontend-owned feedback from stable types or codes, unknown or unmapped failures receive a local generic summary, and failed requests do not trigger the success flow. Changing or omitting server diagnostic text must not change displayed messages or their locale. Exercise the server validator independently with invalid requests that bypass browser checks.

For Slim controller argument changes, exercise real routing and dispatch: verify class-keyed DTO delivery despite parameter renaming or a conflicting name-keyed value, `LogicException` for missing or wrongly typed required attributes before the controller runs, middleware short-circuiting, and distinct DTOs on successive requests through the same application. Verify that the same validated DTO instance reaches the service unless an actual contract difference requires mapping. Verify existing request/response, route-argument, and service injection at the affected invocation boundary.

When a REST resource-creation response changes, verify `201`, `Location` for the actual created identifier and configured base path, the public response body from the returned resource, and secret exclusion. For an explicitly required HTML form action, verify invalid-input rendering without application side effects and a successful redirect rather than a REST JSON creation response. Do not change the endpoint contract incidentally during a validation-only task.

For regex changes, exercise the same valid and invalid examples through the real backend validator and browser HTML5 constraint validation, including relevant Unicode, whitespace, length boundaries, and large invalid input. Check raw trailing line breaks on the backend and account for native input sanitization in browser checks. Verify actual pattern sharing or the documented engine limitation, not just similar pattern text.

Before finalizing, trace the route to its controller and service: field constraints must run only in the input layer, and invalid input must never invoke business operations. Review changed services, command/value constructors, domain policies, and repositories for repeated format, length, or character checks and remove them within the requested scope. Verify that normalization runs once at the input boundary and that a separate service input type exists only for an actual contract difference. Reuse existing business-state coverage unless its behavior changed. Run relevant tests, static analysis, and coding-standard checks available in the application, and report any deliberate departures from these defaults.
