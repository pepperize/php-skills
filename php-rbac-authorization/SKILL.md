---
name: php-rbac-authorization
description: Applies company PHP RBAC authorization conventions. Use when adding, changing, or reviewing roles, permissions, role-to-permission mappings, authorization middleware or attributes, protected controller actions, or object-scoped access decisions.
---

# PHP RBAC Authorization

## Authorization Boundary

Apply coarse application permissions at the HTTP controller boundary through the project's established authorization middleware or attribute mechanism.

- Declare every authorization attribute directly on the public controller method that handles the protected route.
- Do not place authorization attributes on controller classes, even when all current route handlers require the same permission.
- Repeat a shared permission on each protected route handler so every method declaration contains its complete authorization contract.
- When a route handler requires multiple permissions, declare every requirement on that method using the project's supported syntax. Do not combine a class-level baseline permission with method-level additions.
- Keep application and domain services free of HTTP-framework authorization attributes unless a service is itself an explicitly defined security boundary.
- Do not duplicate a controller's coarse permission check inside its application service.

Avoid authorization that must be reconstructed from the class declaration:

```php
#[RequiresPermission(Permission::OwnerAdministrationRead)]
final class OwnerController
{
    public function getOwner(): ResponseInterface
    {
        // ...
    }

    #[RequiresPermission(Permission::OwnerAdministrationWrite)]
    public function postOwner(): ResponseInterface
    {
        // This implicitly requires both read and write permissions.
    }
}
```

Keep each route handler's permission local and explicit:

```php
final class OwnerController
{
    #[RequiresPermission(Permission::OwnerAdministrationRead)]
    public function getOwner(): ResponseInterface
    {
        // ...
    }

    #[RequiresPermission(Permission::OwnerAdministrationWrite)]
    public function postOwner(): ResponseInterface
    {
        // ...
    }
}
```

## Permissions And Roles

- Authorize capabilities such as `owner.read` or `owner.write`; do not authorize controller actions by checking role names.
- Map roles to their granted permissions in one infrastructure-owned RBAC configuration.
- Keep permission names stable and based on the protected application capability rather than controller names or implementation details.
- Treat read and write permissions as independent capabilities. A write route must not acquire a read requirement merely because it shares a controller with a read route.
- If the domain intentionally requires one permission whenever another is granted, encode and test that relationship in the central authorization model.
- Do not introduce role inheritance unless it represents an explicit domain rule.

Map authenticated roles to permissions before request authorization. Controllers and application services should consume the authenticated identity and capability decisions without depending on the RBAC library's concrete types.

## Authentication And Authorization Outcomes

Run authentication before authorization. Preserve the application's established unauthenticated response, such as a login redirect or `401 Unauthorized`. Return `403 Forbidden` when an authenticated identity lacks a required permission.

Routes without a permission declaration are unprotected by permission-based authorization. Verify that every route intended to be protected has an explicit method-level declaration.

## Object-Scoped Rules

Use RBAC for coarse capabilities. Keep ownership, tenant or account scope, lifecycle transitions, and other resource-specific rules in an application authorization policy, application service, or domain service where the relevant object and invariant are available.

Do not encode resource identifiers into permission names or use reflection metadata to enforce domain invariants.

## Required Pre-Final Review

Before finalizing RBAC authorization changes, verify that:

- every protected route handler declares its complete permissions directly on the method;
- no authorization attribute is declared on a controller class;
- controller authorization checks capabilities rather than roles;
- role-to-permission mappings remain centralized;
- write handlers do not accidentally require read permission through controller structure;
- authentication and authorization failures retain their distinct responses; and
- resource-specific rules remain outside the coarse RBAC metadata.
