# Validation Problem Details

Use RFC 9457 as the HTTP error envelope. The `errors` extension below is an application-owned contract, not a schema mandated by the RFC.

## Status Mapping

| Situation | Status |
|---|---|
| Malformed JSON or request syntax | 400 Bad Request |
| Valid syntax violating the request contract, including missing fields or incorrect types | 422 Unprocessable Content |
| Conflict with existing resource state, such as a duplicate unique identifier | 409 Conflict |
| Insufficient permission | 403 Forbidden |

These are application conventions. Preserve an established published contract unless the requested work includes changing it. State conflicts and permission decisions belong to their existing application/domain and authorization flows, not the DTO validator. Unexpected technical or programming failures must remain server errors.

Valid JSON scalars, arrays where an object is required, and explicit JSON `null` are shape violations, not malformed JSON. Preserve object-versus-array shape before associative decoding: `{}` is an object that may be missing required fields, while `[]` is an array; numeric object keys do not make the JSON value an array. Unsupported request media types follow the endpoint's existing 415 handling.

## Public Response Contract

```http
HTTP/1.1 422 Unprocessable Content
Content-Type: application/problem+json
```

```json
{
  "type": "https://example.com/problems/validation-error",
  "title": "Validation failed",
  "status": 422,
  "detail": "The request violates the API contract.",
  "errors": [
    {
      "pointer": "#/email",
      "code": "INVALID_EMAIL"
    }
  ]
}
```

- Replace the example type URI with a stable application-owned URI and document the problem type and extensions. Keep the title stable for that type, except for localization.
- If `status` is included, it must match the actual HTTP response status.
- Use the same envelope for hydration and constraint errors. Report multiple applicable errors consistently without promising exhaustive validation after unsafe hydration.
- Map Symfony constraint violations to stable application codes where clients need them. Do not expose Symfony class names or raw internal identifiers as the public contract.
- Keep `title` and `detail` safe diagnostic text for API consumers. Per-error `detail` is optional diagnostic text; do not require it or add translations solely for browser feedback. Do not include raw values, passwords, tokens, exception messages, or stack traces merely to explain a validation failure.
- Use stable problem types, documented locations, and application-owned codes for programmatic behavior. Apply [Browser Forms](../SKILL.md#browser-forms) when selecting UI feedback; API diagnostics are not browser copy.

## Error Locations

- Map violation paths to field names in the original submitted document, including names changed during hydration. Symfony property paths are not JSON Pointers; do not convert them with blind dot or bracket replacements.
- Preserve nested object segments and zero-based array indexes: `addresses[0].postalCode` may map to `#/addresses/0/postalCode` when those are the submitted names.
- Escape each reference token by replacing `~` with `~0`, then `/` with `~1`. Join the escaped tokens with `/`.
- The example uses URI-fragment pointers. Prefix with `#` and apply RFC 6901 section 6 UTF-8 percent encoding for characters not allowed in URI fragments. For example, a field named `a/b~c` maps to `#/a~1b~0c`; a field named `first name` maps to `#/first%20name`.
- Use `#` for the submitted document itself. Define missing-field pointers as the intended field location, since the absent member cannot resolve in the submitted document. For cross-field violations, choose the relevant field or the document location consistently.
- A body pointer cannot locate a query parameter, route parameter, or header. If those inputs need field-level reporting, document separate location metadata rather than inventing a body pointer.
- Browser consumers must decode fragment and reference-token escaping when matching actionable errors to known controls; [Browser Forms](../SKILL.md#browser-forms) owns unmatched-error feedback.

Test nested collections, renamed fields, `~` and `/` tokens, URI-fragment escaping, root and missing-field locations, and multiple violations where relevant to the mapper.

## Authoritative References

- [RFC 9457: Problem Details for HTTP APIs](https://www.rfc-editor.org/rfc/rfc9457.html)
- [RFC 6901: JSON Pointer](https://www.rfc-editor.org/rfc/rfc6901.html)
- [Symfony Validator configuration](https://symfony.com/doc/current/validation.html)
- [Slim 4 body parsing](https://www.slimframework.com/docs/v4/middleware/body-parsing.html)
