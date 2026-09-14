---
name: php-authentication-security
description: Applies company PHP authentication security conventions. Use when adding, changing, or reviewing login, password hashing or policy, credential verification, Mezzio authentication middleware, sessions, logout, email verification, password reset, authentication throttling or lockout, MFA decisions, or authentication security logging.
---

# PHP Authentication Security

## Preferred Authentication Stack

For compatible PSR-7 and PSR-15 applications, prefer `mezzio/mezzio-authentication` and its maintained adapters. For form login backed by a server-side session, prefer `mezzio/mezzio-authentication-session` and the project's established Mezzio session adapter.

- Do not build a replacement authentication middleware, identity request attribute, or session adapter when the Mezzio components satisfy the requirement.
- Keep Mezzio interfaces, middleware, adapters, and session types in infrastructure and web composition.
- Map the authenticated Mezzio user to an application-owned `CurrentUser` before application code consumes it.
- Keep credential lookup, password verification, account state, and application identity mapping behind project-owned interfaces where the application has rules beyond the adapter contract.
- Use PHP's native `password_hash()`, `password_verify()`, and `password_needs_rehash()` APIs. Do not implement a password hashing algorithm.

Compose protected routes through the established middleware pipeline:

```php
$app->get('/account', [
    SessionMiddleware::class,
    AuthenticationMiddleware::class,
    AttributeAuthorizationMiddleware::class,
    AccountController::class,
]);
```

The exact session and adapter classes may follow the application. Preserve the order: session state must be available before authentication, and authentication must establish an identity before authorization.

## Password Policy And Storage

- For password-only authentication, require at least 15 Unicode characters.
- Allow at least 64 Unicode characters and set a documented, bounded upper limit to protect memory and hashing work. Count characters for the user-facing policy and validate the algorithm's byte limits separately.
- Allow spaces and all printable Unicode characters. Do not impose uppercase, lowercase, digit, symbol, or periodic password-change rules.
- Reject common, expected, context-specific, and known-compromised passwords with a local or privacy-preserving blocklist check. Never send the plaintext password to an external service.
- Allow password managers, paste, and browser autofill.
- Do not trim, case-fold, or otherwise silently rewrite passwords.
- If the application normalizes Unicode, use NFC consistently before the initial hash and every verification. Do not change normalization for existing hashes without a compatible migration strategy.
- Treat the complete accepted password as significant.
- Prefer Argon2id when the deployment supports it and its memory and time cost have been measured on production-like hardware.
- When using bcrypt, explicitly reject passwords over bcrypt's 72-byte input boundary or choose an algorithm without that boundary. A character limit alone does not enforce a byte limit for Unicode input.
- Size the password-hash column for algorithm changes; use at least 255 characters.
- After every successful verification, call `password_needs_rehash()` with the current algorithm and options and persist a replacement hash when needed.
- Use a precomputed dummy hash with the same algorithm and cost as real hashes for unknown-account verification paths. Rotate it when the configured algorithm or cost changes.

Keep hashing policy in one collaborator:

```php
final readonly class PasswordHasher
{
    public function __construct(private array $argonOptions)
    {
    }

    public function hash(string $password): string
    {
        return password_hash($password, PASSWORD_ARGON2ID, $this->argonOptions);
    }

    public function verify(string $password, string $hash): bool
    {
        return password_verify($password, $hash);
    }

    public function needsRehash(string $hash): bool
    {
        return password_needs_rehash(
            $hash,
            PASSWORD_ARGON2ID,
            $this->argonOptions,
        );
    }
}
```

Do not copy these options blindly. Benchmark and configure them at the infrastructure boundary.

## Login Failure And Attack Protection

Every password login requires automated attack protection.

- Limit attempts using both a trusted client key and an account key. Derive the client key from the application's trusted-proxy-aware client address handling.
- Derive the account key with a keyed HMAC of the normalized login identifier. Do not store raw email addresses or usernames in limiter keys.
- Apply the account limiter to known and unknown accounts so the limiter cannot enumerate registered identifiers.
- Verify either the real hash or the dummy hash before returning an ordinary credential failure.
- Return the same public status, redirect, and message for unknown accounts, wrong passwords, and accounts that cannot authenticate, including unverified or disabled accounts. Internal audit events may distinguish them.
- Use temporary, bounded exponential backoff or temporary lockout. Do not permanently lock an account because remote clients can deliberately trigger failures.
- Clear or reduce failure state after successful authentication.
- Return a generic `429 Too Many Requests` response when a client or account bucket is limited without confirming which account exists.
- Fail closed with a temporary `503 Service Unavailable` response when the limiter is required but unavailable. Do not silently allow unlimited login attempts.
- Treat CAPTCHA as an optional additional signal. It does not replace client and account rate limiting.

Derive a non-identifying account bucket:

```php
final readonly class LoginAttemptKeyFactory
{
    public function __construct(private string $limiterKey)
    {
    }

    public function forAccount(string $normalizedLogin): string
    {
        return hash_hmac('sha256', $normalizedLogin, $this->limiterKey);
    }
}
```

Keep the HMAC key outside source control and separate from password hashes and application data.

## Verification And Recovery Tokens

Apply these rules to password-reset and email-verification links:

- Generate at least 32 random bytes with `random_bytes()` and encode them with a URL-safe alphabet.
- Store only a cryptographic digest of the token. The URL contains the bearer token; persistence contains the lookup or comparison digest.
- Give every token a short, explicit expiry and a purpose. A token for one purpose must not satisfy another.
- Validate token syntax and decoded length before querying persistence.
- Compare digests with a timing-safe comparison when the storage lookup does not already provide a constant-shape match.
- Consume a token atomically with the protected state change. Concurrent requests must not both succeed.
- Replace an earlier outstanding token or enforce a small documented bound per account and purpose.
- Do not log tokens, place them in analytics, or expose them to third-party resources.
- Serve token landing pages with `Referrer-Policy: no-referrer` and without third-party scripts or assets that could receive the URL.

Generate the bearer value and its stored digest separately:

```php
$tokenBytes = random_bytes(32);
$token = rtrim(strtr(base64_encode($tokenBytes), '+/', '-_'), '=');
$tokenDigest = hash('sha256', $token, true);
```

For password reset:

- Return the same public status and message for known, unknown, disabled, and unverified accounts.
- Keep the execution shape similar. Prefer queued delivery so SMTP behavior does not reveal account existence through response time.
- Rate-limit requests with both client and HMAC-derived account keys.
- Do not lock an account because reset links were requested.
- After a successful reset, invalidate every sibling reset token and all active authenticated sessions for that account.
- Do not automatically sign the user in after reset. Require a normal login with the new password.

## Session Lifecycle

- Enable strict session-ID handling and reject uninitialized IDs when the session implementation supports it.
- Rotate the session ID after login and every privilege-level change. On logout, invalidate server-side authenticated state and expire the session cookie; create a fresh anonymous session only if the application needs one.
- Configure cookies with `Secure`, `HttpOnly`, an appropriate `SameSite` value, the narrowest practical `Path`, and no unnecessary `Domain`.
- Enforce both an idle timeout and an absolute timeout on the server.
- Store the immutable authentication time separately from last activity. Updating activity must never extend the absolute lifetime.
- Revalidate account status and authorization freshness on every request. Either reload roles or compare an account-owned session/security version against the session.
- Increment the session/security version after password reset, password change, account disablement, and role or privilege changes.
- Ensure logout and security-version invalidation make old server-side state unusable, even if an old cookie is replayed.
- Store sessions outside public directories and verify expired-session garbage collection for the selected adapter.
- Send `Cache-Control: no-store` on responses containing authenticated or recovery-sensitive data.

A session should carry stable identity and revocation data rather than becoming the source of truth for permissions:

```php
$session->set('account_id', $accountId->toString());
$session->set('authenticated_at', $clock->now()->getTimestamp());
$session->set('last_activity_at', $clock->now()->getTimestamp());
$session->set('security_version', $account->securityVersion());
```

## MFA Decisions

Follow the project's threat model and ADRs when deciding whether MFA is required. Do not introduce or omit MFA silently.

When password-only authentication is accepted, require the compensating controls in this skill: strong password handling, client and account throttling, bounded lockout or backoff, secure recovery, revocable sessions, and security-event logging.

When implementing MFA, use a maintained protocol implementation, protect recovery codes like passwords, make enrollment and reset high-assurance operations, and invalidate sessions after disabling or resetting factors.

## Required Pre-Final Review

Before finalizing authentication changes, verify that:

- the Mezzio authentication stack is used when compatible and third-party types remain at infrastructure boundaries;
- password length, Unicode, blocklist, algorithm limits, dummy verification, and rehash behavior are explicit and tested;
- login limiting uses client and HMAC-derived account keys and fails closed if its required state is unavailable;
- public login and reset outcomes do not reveal whether an account exists or can authenticate;
- recovery and verification tokens are random, hashed at rest, expiring, bounded, and atomically single-use;
- password reset invalidates sibling tokens and active sessions;
- session IDs rotate at authentication boundaries and idle, absolute, and security-version checks run server-side; and
- sensitive authentication values are absent from logs, analytics, and third-party requests.
