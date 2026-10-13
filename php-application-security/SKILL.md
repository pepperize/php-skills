---
name: php-application-security
description: Applies company PHP application security guidance. Use when adding, changing, or reviewing validation of external input, regex validation, request parameters, URLs, S3 keys, file paths, identifiers, or persisted data that may affect security or availability.
---

# PHP Application Security

## Request Validation

Treat external input as untrusted even when browser validation succeeds. Within the backend, validate it only at the input boundary; independent browser validation is appropriate for usability and never authorizes a request. For typical PHP HTTP applications, use Symfony Validator attributes on input DTOs, executed by route middleware before controllers and services. Use `php-request-validation` for hydration, constraints, middleware, and Problem Details.

Do not repeat input checks in services, application commands, domain objects, repositories, or output code, or introduce a domain policy merely to recheck email syntax, password composition, lengths, or allowed input values. Other external entry points validate their own input before calling application services. Business decisions about current state, permissions, ownership, uniqueness, and lifecycle transitions remain with the operation that owns them.

Validate at input; escape or encode at output for its actual context. Preserve original values in DTOs and storage. Use `php-templating` for HTML output and `php-logging-exceptions` for log encoding; valid input still requires context-appropriate output handling.

## Regex Safety

Regex is acceptable for validation, but do not use patterns with nested, ambiguous, or repeated repetitions that can cause excessive backtracking or stack overflow for large inputs.

Use one full-value regex per field in the input layer, preferably sharing its canonical body with frontend HTML5 `pattern` as described in `php-request-validation`. Do not split a field rule into multiple regex constraints or repeat it in downstream code. A built-in constraint or deterministic input-layer validator remains preferable when the format cannot be expressed safely by one regex.

Treat regexes over external input as security-sensitive, including request URLs, query parameters, selectors, S3 keys, file paths, identifiers, and persisted data entering through an external-data adapter. Validate those values at that input boundary, not again in downstream services.

When a regex contains repeated groups inside repeated groups, review it for ReDoS or stack-overflow risk before committing. If the safe regex becomes hard to reason about, prefer deterministic validation in the input layer: normalize, split into bounded parts, enforce lengths/counts, and validate characters with simple loops.

When replacing or changing a regex flagged by static analysis, add a focused large-invalid-input test.
