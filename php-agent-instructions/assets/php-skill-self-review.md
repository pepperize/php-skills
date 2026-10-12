<!-- php-skills:self-review:start -->
## PHP Skill Self Review

After making PHP code, test, or skill changes, review the diff before the final response.

- Treat relevant PHP skills as active decision guides, not background reading.
- Before editing, name the applicable skills and the exact rules that constrain naming, exceptions, logging, validation, authentication, authorization, testing, migrations, and architecture.
- Use `php-domain-clarification` before coding when domain rules, identifiers, persistence shape, scoping, or externally visible behavior are unclear.
- Use `php-solid-review` for explicit code, architecture, and design reviews and to self-review non-trivial implementations against the engineering principles that materially apply.
- Use `php-readable-code` for naming, guard clauses, factories, utilities, and readability.
- Before finalizing, verify that every new or renamed injected dependency and its test collaborators use the complete declared short type in lower camel case, never a plural resource alias.
- Use `php-templating` for server-rendered controllers, page templates, partials, localized email bodies, and template-input changes.
- Use `php-testing-style` for all test naming, mocks, unit/integration boundaries, assertions, layout, and verification scope.
- Use `php-application-security` for input validation, regex safety, and other application-security-sensitive code paths.
- Use `php-request-validation` for request DTO hydration, Symfony constraints, validation middleware, Problem Details, and browser submission handling. Default forms to JavaScript-managed submissions that preserve inputs and display server errors; ordinary HTML submission flows require an explicit project or task requirement.
- Use `php-authentication-security` when adding, changing, or reviewing login, credentials, password policy or hashing, sessions, logout, account recovery or verification, authentication throttling, or MFA.
- Use `php-rbac-authorization` when adding, changing, or reviewing roles, permissions, authorization attributes, protected routes or controllers, object-scoped access, or RBAC mappings.
- Use `php-logging-exceptions` and `php-database-migrations` when changes touch those areas.
- Use `php-shared-hosting-deployment` for deployment work only when root `AGENTS.md` contains the shared-hosting activation marker and exactly one supported database marker. Select only that SQLite or MariaDB example; absent or conflicting markers keep the skill inactive.
- Use `php-clean-architecture` and `php-ddd-architecture` only when this project's instructions explicitly state those architectures.
- Before finalizing, review new or changed helper methods with `php-readable-code`.
- Before finalizing, review thrown/caught exceptions and logging decisions with `php-logging-exceptions`.
- During design review, name the applicable principle in each meaningful finding. Do not emit a principle checklist, manufacture violations, or recommend speculative abstractions.
- A design self-review may conclude that no relevant principle violation was found.
- Before finalizing a server-rendered page, verify that it receives one typed page ViewModel, structured nested values use ViewModels, and render arrays exist only as template-engine adapters.
- Before finalizing a localized email body, verify that each distinct outcome and supported locale has one complete template, long-form prose is absent from translation catalogs and line assembly, rendering does not apply a page layout, and real-renderer tests cover each combination. When multiple email families share a locale-qualified filename convention, verify that template-path construction and locale context use a shared application renderer with closed template and locale types.
- Do not add defensive branches unless the domain/API path can actually produce that state.
- Fix meaningful issues found during self-review before finalizing.
- Keep cleanup scoped to the requested change.
<!-- php-skills:self-review:end -->
