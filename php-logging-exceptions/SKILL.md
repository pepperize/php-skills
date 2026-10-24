---
name: php-logging-exceptions
description: Applies company PHP logging and exception placement guidance. Use when adding or reviewing logging, exception handling, helper methods, factories, or domain-relevant error paths.
---

# PHP Logging And Exceptions

## Logging

Do not hide domain-relevant logging in helper methods such as `getXOrWarn(...)`.

Log where the problem is detected so the log points to the real origin.

## Log Safety Review

Before finalizing logging changes:

- Keep log calls where the failure or skip decision is made.
- Extract collaborators only for formatting, encoding, mapping, or classification, not to hide domain-relevant logging.
- Treat external data, exception values, validation paths, and rejected values as unsafe before logging.
- Encode unsafe log values at the last formatting boundary before they are passed to the logger.
- Do not pass raw dynamic values into logger placeholders or concatenated log messages when the value may come from requests, persisted data, external systems, files, config, generated URLs, S3 keys, exception messages, or validation failures. Validate inputs at the boundary where feasible, but also encode unsafe log values at the final logging boundary with a project-approved `encode...ForLog` helper. Keep the original value for domain, storage, and API behavior; only encode the value passed to the logger. Keep exceptions unencoded and pass them through the logger's established exception mechanism.
- When adding a reusable log encoder, cover CR, LF, CRLF, tabs, quotes, and script-like payloads in focused unit tests.
- Name extracted log-formatting methods with verb phrases such as `format...`, `encode...`, or `create...`.

## Authentication And Authorization Events

Record security-relevant outcomes at the boundary that knows the result. At minimum, cover:

- login succeeded, failed, throttled, or temporarily locked;
- authenticated session invalidated or rejected by expiry or security-version checks;
- password reset completed;
- authorization denied; and
- role or privilege granted, revoked, or rejected.

Use stable event names, the actor account ID when authenticated, the affected account ID when applicable, the permission or role identifier, outcome, reason code, and timestamp. For unauthenticated client or account correlation, use keyed pseudonymous identifiers with planned key rotation.

Never log plaintext passwords, password hashes, reset or verification bearer tokens, session IDs, CSRF tokens, raw email addresses, raw usernames used for login, or raw IP addresses. Encode every remaining dynamic field for the log format. Rate-limit or aggregate repetitive login and denial events so an attacker cannot exhaust log storage or hide useful signals in noise.

## Exceptions

Throw exceptions where the problem originates.

A focused helper may throw a specific exception for a failure it detects and owns. For example, a request-construction helper may report a missing field while the middleware decides the HTTP response. Keep response construction and policy logging out of that helper. Avoid moving a throw into a helper that lacks the information or responsibility to understand the failed condition.

Do not add application or domain exceptions only to translate malformed HTTP requests into HTTP responses. Keep exceptions for raw request-construction failures in the web/infrastructure input adapter and map them through the established HTTP error boundary. A result object remains appropriate when the contract requires accumulated errors or partial values; exceptions are not mandatory for every failed operation.

## Repository Conflict Exceptions

- Repository writes that fail because an entity already exists throw a generic `EntityExistsException` declared by the repository contract. Keep the generic exception in the layer that owns that contract.
- Application services catch `EntityExistsException` and translate it into the appropriate resource- or use-case-specific exception, such as `UserAlreadyExistsException` in `UserService`. Keep that specific exception in the application module alongside the owning service.
- Preserve the original exception as `previous` at each translation boundary.
- Translate only failures that establish an entity-exists conflict. Keep unrelated storage and integrity failures technical.

## Exception Boundaries

- Do not catch broad `Throwable` in orchestration code just to log and convert it into `null`, an empty array, or a generic failure result.
- Only catch exceptions when the collaborator documents or clearly owns a recoverable failure case that the caller can handle meaningfully.
- Scope a catch to the operation whose failure it translates. In particular, keep constraint validation and downstream request handling outside a catch intended for DTO construction, so the same exception type raised later is not reported as a failure of the submitted body.
- If a method only filters or maps already-loaded data, "no matches" should be a normal empty result, not an exception path.
- Do not branch on human-readable exception or HTTP error message text for control flow. Classify external API failures using stable contract signals such as HTTP status, documented machine-readable error codes, typed exceptions, or structured response fields. If a status code has multiple business meanings, clarify or improve the upstream contract instead of matching message text.
