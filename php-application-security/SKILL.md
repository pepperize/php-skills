---
name: php-application-security
description: Applies company PHP application security guidance. Use when adding, changing, or reviewing validation of external input, regex validation, request parameters, URLs, S3 keys, file paths, identifiers, or persisted data that may affect security or availability.
---

# PHP Application Security

## Request Validation

Treat external input as untrusted even when browser checks succeed. Validate once at the entry boundary under [Validation Ownership](../php-request-validation/SKILL.md#validation-ownership); keep business-state decisions in their owning operation and avoid downstream field revalidation.

## Output Handling

Validate at input; escape or encode at the actual output context. Preserve original values in DTOs and storage rather than pre-escaping them. Valid input still requires context-appropriate output handling.

Use [PHP Templating](../php-templating/SKILL.md#template-engine-and-escaping) for HTML versus plain text, and [Log Safety Review](../php-logging-exceptions/SKILL.md#log-safety-review) for log encoding. Handle JavaScript, CSS, and URL contexts separately when they arise.

## Regex Safety

Regex is acceptable for validation, but do not use patterns with nested, ambiguous, or repeated repetitions that can cause excessive backtracking or stack overflow for large inputs.

Use the input contract's [One Regex Per Field](../php-request-validation/SKILL.md#one-regex-per-field) rule for placement and frontend sharing; this section owns execution-safety checks.

Treat regexes over external input as security-sensitive, including request URLs, query parameters, selectors, S3 keys, file paths, identifiers, and persisted data entering through an external-data adapter. Validate those values at that input boundary, not again in downstream services.

When a regex contains repeated groups inside repeated groups, review it for ReDoS or stack-overflow risk before committing. If the safe regex becomes hard to reason about, prefer deterministic validation in the input layer: normalize, split into bounded parts, enforce lengths/counts, and validate characters with simple loops.

When replacing or changing a regex flagged by static analysis, add a focused large-invalid-input test.
