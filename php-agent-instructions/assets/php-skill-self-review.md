<!-- php-skills:self-review:start -->
## PHP Skill Self Review

After making PHP code, test, or skill changes, review staged and unstaged diffs and task-created untracked files before the final response. Use `git status --short` to include new files that `git diff` omits.

These are decision and review reminders. Read the named skill and its linked owner sections for the complete rules; do not maintain another policy catalog in project instructions.

- Treat relevant PHP skills as active decision guides. Before editing, name the applicable skills and the exact rules that constrain the change.
- Use `php-domain-clarification` before coding when domain rules, identifiers, persistence shape, scoping, or externally visible behavior are unclear.
- Use `php-readable-code` before class naming to identify the primary responsibility. Follow its pre-final review for new or renamed classes, classes whose responsibility changed, aliases, injected dependencies, methods, and helpers; correct affected callers/tests/docs and report new collaborators' role, returned product, and naming decision.
- Name injected constructor parameters, properties, and test collaborators after the declared short type in lower camel case after dropping a trailing `Interface`; preserve other role suffixes and avoid plural resource aliases. Follow `php-readable-code` for the complete naming rule.
- For REST resource work, apply `php-api-endpoints` and read its worked User reference. Check the Controller -> Service -> Repository flow, entity/DTO factories, and the owning persistence policy. Use `php-readable-code` for resource and CRUD names.
- For completed REST creation, check that the service returns a public DTO such as `UserDto` from the persisted entity and the controller delegates `201`, member `Location`, and the representation with its identifier and no secrets to the responder. The complete contract belongs to `php-api-endpoints`.
- Distinguish REST resource endpoints, rendered pages, and explicitly required traditional HTML actions. A rendered form calling REST follows REST rules; HTML pages retain ViewService/Renderer and traditional actions retain capability names and HTML errors/redirects.
- Use `php-request-validation` for hydration, Symfony constraints, middleware, DTO sharing, Problem Details, and submissions. Check input-only field validation and one-time normalization, the same validated service DTO unless contracts differ, and one full-value regex preferably shared with HTML5 `pattern`.
- In Slim, check class-keyed typed DTO delivery and invocation-boundary `LogicException` before fallback; keep submitted DTOs out of the shared container. Follow the binding reference in `php-request-validation`.
- For browser forms, follow `php-request-validation`: JavaScript-managed local validation, preserved inputs, and frontend-owned localized feedback selected from stable server types/codes. Never display server diagnostics; unknown failures use a local generic summary. Ordinary HTML submission requires an explicit requirement.
- Use `php-templating` for templates, typed page ViewModels, and localized content. Check one complete page ViewModel and complete email templates per locale/outcome, with the real-renderer coverage that skill requires.
- Use `php-testing-style` for test naming, mocks, assertions, layout, unit/integration boundaries, and verification scope, including security integration and route-inventory coverage when affected.
- Use `php-application-security` for regex safety and contextual output handling; keep stored and DTO values unescaped.
- Use `php-authentication-security` for login, credentials, password handling, sessions, logout, recovery/verification, throttling, and MFA.
- Use `php-rbac-authorization` for roles, permissions, authorization attributes, protected routes/controllers, object-scoped access, and RBAC mappings.
- Use `php-logging-exceptions` for exceptions/logging and `php-database-migrations` for migration work.
- Use `php-shared-hosting-deployment` only for deployment work when root `AGENTS.md` has the hosting marker and exactly one SQLite or MariaDB database marker; select that example and follow its activation guard.
- Use `php-clean-architecture` and `php-ddd-architecture` only when the project's main instructions explicitly state those architectures.
- Use `php-solid-review` for explicit code, architecture, and design reviews and self-review of non-trivial implementations. Name the applicable principle in material findings; do not emit a principle checklist or manufacture violations. A review may conclude that no relevant principle violation was found.
- Check defensive branches against reachable domain/API states using `php-readable-code`. Fix meaningful self-review findings within the requested scope before finalizing.
<!-- php-skills:self-review:end -->
