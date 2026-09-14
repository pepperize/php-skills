---
name: php-templating
description: Applies company PHP templating conventions for typed presentation models, established engine selection, layouts, partials, output escaping, interface translation, and source-controlled localized page and email content. Use when defining template inputs, choosing or changing a PHP template engine, writing or reviewing page or email templates, implementing template escaping and translation helpers, or organizing localized static content.
---

# PHP Templating

## Template Engine And Escaping

Respect the template engine already established by the project. Do not replace Twig, Blade, or another existing template engine merely because a different engine would be preferred for a new project. Treat the `slim/php-view` guidance below as the default only when the project has not already selected a template engine.

For Slim-based projects, prefer `slim/php-view` with native PHP templates, using its layouts and partials for reuse. Templates must support direct step-by-step debugging with Xdebug without template compilation.

When using `slim/php-view`:

- Configure the layout on the renderer with `$renderer->setLayout('layout.php')`.
- Render reusable template parts with `$this->fetch('partials/contact.php', ['locale' => $locale, 'contact' => $contact])` so their typed input and required rendering context are explicit.
- Do not use APIs from other template engines such as `$this->layout()`, or bypass PHP-View's partial support with raw `include` calls.

Escape HTML output explicitly through a shared `html(string $value): string` helper using `htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8')`. Do not apply HTML escaping to plain-text output.

Prefer built-in PHP functionality over additional dependencies when it meets the actual requirements. Introduce another template engine or escaping library only when a concrete requirement justifies it. Handle JavaScript, CSS, and URL contexts separately if they arise.

Start with the framework's simplest suitable option, and justify additional features against actual requirements.

## Typed Page ViewModels

Every server-rendered page must receive one page-specific ViewModel containing its application-provided template data.

- Name presentation models `<Concept>ViewModel`. The template is the view; do not name presentation data classes `<Concept>View` or `<Concept>ViewData`.
- Prefer `final readonly class` for ViewModels.
- Structure a page ViewModel by stable semantic page components such as metadata, header, content, and legal navigation.
- Give structured nested data its own ViewModel. Do not represent contacts, navigation links, language options, or similar records as associative array shapes.
- Use native arrays only for collections and document their element type as `list<SomeViewModel>`.
- Do not create ViewModels for incidental HTML elements. Model concepts that carry meaningful presentation data or correspond to reusable components.
- Keep ViewModels free of requests, responses, route parsers, renderers, repositories, domain entities, infrastructure objects, HTML markup, and escaping behavior.
- In a server-rendered flow with a frontend ViewService, that service returns the complete page-specific ViewModel. The controller must not assemble metadata, content, or shared component ViewModels around a partial service result.
- At the page-render boundary, pass one page ViewModel. With `slim/php-view`, use `['page' => $page]`; the array exists only because the framework binds names to template variables.
- Keep established renderer terminology. A collaborator that renders a template and ViewModel into an HTML response body remains a renderer; do not rename it to a factory merely because rendering creates output.
- For partials, pass the relevant nested ViewModel plus unavoidable rendering context such as locale or a CSS variant. Do not flatten the component back into scalar or associative-array fields.

Avoid a loose render-data map with nested array shapes:

```php
$this->templates->render($response, 'privacy-policy.php', [
    'locale' => $locale,
    'homeUrl' => $homeUrl,
    'operator' => [
        'name' => $operator->name,
        'protectedEmail' => $protectedEmail,
    ],
    'recipients' => $recipients,
]);
```

Prefer a ViewModel hierarchy that follows the page:

```php
final readonly class PrivacyPolicyPageViewModel implements PageViewModel
{
    public function __construct(
        public PageMetadataViewModel $metadata,
        public SiteHeaderViewModel $header,
        public PrivacyPolicyContentViewModel $content,
        public LegalNavigationViewModel $legalNavigation,
    ) {
    }

    public function metadata(): PageMetadataViewModel
    {
        return $this->metadata;
    }
}

final readonly class PrivacyPolicyContactViewModel
{
    /** @param list<string> $postalAddressLines */
    public function __construct(
        public string $name,
        public array $postalAddressLines,
        public string $protectedEmail,
    ) {
    }
}

final readonly class PrivacyPolicyContentViewModel
{
    /** @param list<PrivacyPolicyRecipientViewModel> $recipients */
    public function __construct(
        public PrivacyPolicyContactViewModel $operator,
        public array $recipients,
        public string $version,
    ) {
    }
}

final readonly class PrivacyPolicyRecipientViewModel
{
    public function __construct(
        public PrivacyPolicyContactViewModel $contact,
        public ?string $privacyPolicyUrl,
    ) {
    }
}
```

The frontend ViewService returns the complete page ViewModel, and the controller adapts it to PHP-View only at the final boundary:

```php
final class PrivacyPolicyViewService
{
    public function fetchPage(Locale $locale): PrivacyPolicyPageViewModel
    {
        $metadata = new PageMetadataViewModel($locale, 'Privacy policy');
        $header = $this->siteHeaderFactory->createForLegalPage(
            $locale,
            'privacy-policy',
        );
        $content = $this->fetchContent();
        $legalNavigation = $this->legalNavigationFactory->create(
            $locale,
            'privacy-policy',
        );

        return new PrivacyPolicyPageViewModel(
            $metadata,
            $header,
            $content,
            $legalNavigation,
        );
    }
}

$selectedLocale = Locale::from($locale);
$page = $this->privacyPolicyViewService->fetchPage($selectedLocale);
$renderedResponse = $this->templates->render(
    $response,
    'privacy-policy.php',
    ['page' => $page],
);

return $renderedResponse
    ->withHeader('Content-Language', $selectedLocale->value)
    ->withHeader('Content-Type', 'text/html; charset=UTF-8');
```

The page template and partial keep their type information:

```php
/** @var PrivacyPolicyPageViewModel $page */

<?= $this->fetch('partials/privacy-policy-content.php', [
    'locale' => $page->metadata->locale,
    'content' => $page->content,
]) ?>
```

Before finalizing a server-rendered page change:

- Inspect each changed `render()` call and verify that application data enters through one page ViewModel.
- Inspect associative arrays passed to templates and replace structured records with typed ViewModels.
- Confirm that the ViewModel hierarchy follows semantic page components rather than incidental markup.
- Confirm that collection elements are typed ViewModels.
- When a frontend ViewService is present, confirm that it returns the complete page ViewModel and the controller does not construct page components.
- Confirm that templates escape dynamic output at the output location.

## Interface Translation In Templates

Use `_t()` for interface messages such as navigation labels, buttons, form labels, validation messages, accessibility labels, and short parameterized text.

- Use the source-language text itself as the translation key, rather than symbolic identifiers such as `homepage.title`.
- Expose translations in PHP templates through a `_t()` helper that accepts the source text and optional named parameters. The template helper names `_t()` and `html()` are intentional conventions and take precedence over general verb-based helper naming rules.
- Support locale-aware pluralization through ICU MessageFormat, including the plural categories required by each supported language. Do not reduce pluralization to a singular/plural boolean.
- Pass dynamic values as named parameters instead of concatenating translated fragments.
- Resolve the locale for each render; do not let a previous render's locale leak into a later render.
- Return unescaped text from `_t()` and escape it at the output location when needed. For HTML, use the shared `html()` helper, for example `html(_t('Hello {name}', ['name' => $name]))`. Do not apply HTML escaping to plain-text output.

Example with pluralization in an HTML template:

```php
<?= html(_t(
    '{count, plural, =0 {No children} one {One child} other {# children}}',
    ['count' => $childCount],
)) ?>
```

## Localized Page Content

Choose the content source before selecting the localization approach:

- When localized content is stored in a database or CMS, use the project's content model and established markup sanitization rules. Do not duplicate that content in locale-specific templates.
- When long-form page content is static and source-controlled, keep each complete translation together with its semantic markup and formatting in a locale-specific partial using the project's existing template engine.
- Name localized content partials with the content purpose first and the locale as a suffix. For example, use `partials/home-content.de.php` for native PHP or `partials/home-content.de.html.twig` for Twig, subject to the project's existing filename conventions.
- Avoid locale-only filenames such as `de.php` or `de.html.twig`, which are difficult to identify in search results.
- Render the partial through the established template engine. Use `$this->fetch(...)` with `slim/php-view`, `{% include %}` with Twig, or the corresponding mechanism provided by the selected engine.
- Do not place formatted long-form content in the interface translation catalog or construct it from translated fragments.
- Select the partial with an exhaustive mapping of supported locales unless the established framework already provides an equally explicit locale-template resolution mechanism.
- Keep section identifiers and structural landmarks consistent across locale partials.
- Follow the selected engine's escaping rules for dynamic values. Source-controlled static markup may be authored directly in the partial.
- Render every supported locale in integration tests. Verify representative localized content, required structure, and meaningful formatting.
- Do not silently fall back to another language for authored content unless the product explicitly requires that behavior.

## Localized Email Bodies

When implementing or reviewing source-controlled localized email bodies, read
[references/localized-email-bodies.md](references/localized-email-bodies.md) for native PHP examples.

- Treat a multi-sentence, paragraph-based, or structurally formatted email body as long-form authored content. Render it through the project's established template engine instead of concatenating strings, assembling line arrays, or storing body paragraphs in the interface translation catalog.
- Keep each complete translation in a locale-specific template. Create a separate complete template for every semantically distinct message outcome whose body differs, so a reviewer can read the exact outgoing message without following outcome-selection branches.
- Do not extract translated prose into shared partials when doing so would force a reviewer to reconstruct the message. Reuse focused formatting helpers for dynamic values instead.
- A complete template may conditionally render genuinely optional data, such as a notes section. It must not select between different message outcomes.
- Name templates with the message purpose and outcome first and the locale as a suffix. Avoid locale-only filenames.
- Make locale-specific template selection total and fallback-free. When several email families follow the same filename convention, represent locale-independent template names with an application-owned `EmailBodyTemplate` enum and derive the filename from that enum and the supported locale enum instead of repeating locale matches in each factory.
- Centralize the shared filename convention and locale rendering context in a concrete `LocalizedEmailBodyRenderer`. Always pass the typed locale into the template data as rendering context, even when the current body uses it only to select the locale-qualified filename. Keep purpose-specific email factories responsible for outcome selection, subjects, recipients and transport metadata.
- Let the shared renderer delegate to the established template engine's layout-free string-rendering operation. With slim/php-view, use `fetch()` without enabling the configured HTML page layout; do not mutate the shared renderer's layout for an email render. Do not add a mirror interface unless the project's architecture or multiple renderer implementations require one.
- In an App/Domain/Infrastructure project without an explicit Clean Architecture rule, place the shared renderer with application presentation or email composition. Keep template-engine construction and configuration in Infrastructure, and keep template identifiers and renderers out of Domain.
- Build template paths only from closed application-owned template identifiers and typed locales. Do not accept request strings or other external values as template names.
- Keep recipients, subjects, sender, Reply-To, content type, and other transport metadata outside the body template.
- Keep short subjects and short grammar-sensitive fragments in the established translation system. The _t() helper may be used for ICU pluralization or another short parameterized phrase, but not for body paragraphs, greetings, labels, or signatures that belong to the complete localized template.
- Pass structured dynamic template data through a purpose-specific immutable ViewModel. A single obvious value, such as a generated confirmation URL, may be passed as a purpose-named scalar.
- Keep email ViewModels free of requests, responses, repositories, domain entities, transport messages, renderers, HTML markup, and escaping behavior.
- Apply output handling for the actual email format. Do not HTML-escape plain-text output; escape dynamic HTML email output for its output context.
- Preserve intentional whitespace, optional-section spacing, line endings, and the final newline as observable message behavior.
- Remove obsolete body-only translation entries after confirming that no callers remain.
- Render every supported locale and message outcome with the real template engine in integration tests. Derive locale coverage from `Locale::cases()` so adding a locale exposes missing templates. With PHPUnit, compare each complete expected body to the actual body using `self::assertSame()`; keep service tests focused on sending, ordering, headers, and failure behavior.
