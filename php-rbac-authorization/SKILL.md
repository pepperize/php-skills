---
name: php-rbac-authorization
description: Applies company PHP RBAC authorization conventions. Use when adding, changing, or reviewing roles, permissions, role-to-permission mappings, authorization middleware or attributes, protected controller actions, or object-scoped access decisions.
---

# PHP RBAC Authorization

## Preferred RBAC Stack

Use RBAC as the standard model for coarse application authorization.

- For compatible PHP applications, prefer `laminas/laminas-permissions-rbac` as the RBAC engine.
- In a Mezzio application that uses Mezzio Authorization, prefer `mezzio/mezzio-authorization-rbac` as the integration adapter.
- Do not build a custom role graph, permission inheritance engine, or RBAC evaluator when the Laminas components satisfy the requirement.
- Use another authorization model only when an explicit project requirement cannot be represented safely by RBAC. Record that decision in the project's architecture documentation.
- Keep Laminas and Mezzio concrete types in infrastructure adapters, factories, middleware, and configuration.
- Expose an application-owned `AuthorizationService`, `Permission` enum, `CurrentUser`, and authorization attributes to the rest of the application.

For example, keep permission vocabulary and the authorization port independent of Laminas:

```php
enum Permission: string
{
    case OwnerRead = 'owner.read';
    case OwnerWrite = 'owner.write';
}

interface AuthorizationService
{
    public function isGranted(
        CurrentUser $currentUser,
        Permission $permission,
    ): bool;
}
```

An infrastructure implementation may delegate each role and permission value to `Laminas\Permissions\Rbac\Rbac::isGranted()`.

## Authorization Boundary

Apply coarse application permissions at the HTTP controller boundary through typed, method-level PHP attributes consumed by authorization middleware. Attributes keep authorization declarations beside the protected entry point and keep checks out of business code.

- Declare every authorization attribute directly on the public controller method that handles the protected route.
- Define `RequiresPermission` as a typed, repeatable, method-only attribute. Its constructor accepts `Permission`, not an arbitrary string or role name.
- Do not place authorization attributes on controller classes, even when all current route handlers require the same permission.
- Repeat a shared permission on each protected route handler so every method declaration contains its complete authorization contract.
- Treat multiple `RequiresPermission` attributes as AND requirements unless a separate, explicitly named any-of policy is part of the application contract.
- Keep application and domain services free of HTTP-framework authorization attributes unless a service is itself an explicitly defined security boundary.
- Do not duplicate a controller's coarse permission check inside its application service.

Use a closed, typed attribute contract:

```php
#[Attribute(Attribute::TARGET_METHOD | Attribute::IS_REPEATABLE)]
final readonly class RequiresPermission
{
    public function __construct(public Permission $permission)
    {
    }
}
```

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

## Protected Route Composition

Treat the controller attribute and the route middleware as one authorization contract.

- Prefer a central route registrar, route group, or infrastructure composer that installs session, authentication, attribute authorization, and CSRF middleware in the correct order.
- Apply CSRF protection to authenticated state-changing browser routes in addition to authentication and authorization.
- If the framework requires explicit middleware chains on each route, add a route-inventory integration test that inspects every registered route and handler.
- When attribute authorization middleware is attached, failure to resolve the final callable or its security declaration is a configuration error. Throw or deny access; never delegate to the controller as though the route were public.
- Use a method-level `RequiresAuthentication` attribute for authenticated routes with no permission requirement, including logout.
- Keep public bearer-capability routes, such as password-reset token endpoints, out of authenticated route groups and place them on an explicit public-route allowlist in route-inventory tests.

For example, a state-changing handler declares its complete capability locally while infrastructure composes the checks:

```php
final class OwnerController
{
    #[RequiresPermission(Permission::OwnerWrite)]
    public function postOwner(
        ServerRequestInterface $request,
    ): ResponseInterface {
        $currentUser = $this->currentUserFactory->createFromRequest($request);

        $this->updateOwner->execute($currentUser);

        return $this->responseFactory->createSuccess();
    }
}

$app->post('/owner', [
    SessionMiddleware::class,
    AuthenticationMiddleware::class,
    AttributeAuthorizationMiddleware::class,
    CsrfMiddleware::class,
    OwnerController::class,
]);
```

Do not move the Laminas RBAC object into the controller.

## Authentication And Authorization Outcomes

Run authentication before authorization. Preserve the application's established unauthenticated response, such as a login redirect or `401 Unauthorized`. Return `403 Forbidden` when an authenticated identity lacks a required permission.

Routes without a permission or authentication declaration are public. Verify that public access is intentional and that every non-public route has an explicit method-level declaration.

## Authorization Freshness And Privilege Changes

- Reload roles for each authenticated request or use a reliable account-owned session/security version that invalidates cached identity data immediately after a role change.
- Make role grants and revocations effective on the next request. Do not trust roles copied into a long-lived session without a revocation check.
- Enforce invariants such as "at least one active administrator remains" transactionally in the application or domain operation that changes roles.
- Record successful and rejected privilege changes through the project's security logging boundary.
- Rotate or invalidate affected sessions after privilege changes according to the authentication skill.

## Object-Scoped Rules

Use RBAC for coarse capabilities. Keep ownership, tenant or account scope, lifecycle transitions, and other resource-specific rules in an application authorization policy, application service, or domain service where the relevant object and invariant are available.

Do not encode resource identifiers into permission names or use reflection metadata to enforce domain invariants.

## Required Pre-Final Review

Before finalizing RBAC authorization changes, verify that:

- Laminas RBAC and the Mezzio adapter are used when compatible, behind application-owned contracts;
- every protected route handler declares its complete permissions directly on the method;
- no authorization attribute is declared on a controller class;
- controller authorization checks capabilities rather than roles;
- role-to-permission mappings remain centralized;
- write handlers do not accidentally require read permission through controller structure;
- authentication and authorization failures retain their distinct responses;
- middleware resolution errors fail closed and route inventory covers public, authenticated, authorized, and CSRF-protected routes;
- role changes are fresh on the next request and preserve privilege invariants; and
- resource-specific rules remain outside the coarse RBAC metadata.
