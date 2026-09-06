---
name: php-templating
description: Applies company PHP templating conventions for established engine selection, layouts, partials, output escaping, interface translation, and source-controlled localized page content. Use when choosing or changing a PHP template engine, writing or reviewing templates, implementing template escaping and translation helpers, or organizing localized static content.
---

# PHP Templating

## Template Engine And Escaping

Respect the template engine already established by the project. Do not replace Twig, Blade, or another existing template engine merely because a different engine would be preferred for a new project. Treat the `slim/php-view` guidance below as the default only when the project has not already selected a template engine.

For Slim-based projects, prefer `slim/php-view` with native PHP templates, using its layouts and partials for reuse. Templates must support direct step-by-step debugging with Xdebug without template compilation.

When using `slim/php-view`:

- Configure the layout on the renderer with `$renderer->setLayout('layout.php')`.
- Render reusable template parts with `$this->fetch('partials/contact.php', ['name' => $name])` so their input is explicit.
- Do not use APIs from other template engines such as `$this->layout()`, or bypass PHP-View's partial support with raw `include` calls.

Escape HTML output explicitly through a shared `html(string $value): string` helper using `htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8')`. Do not apply HTML escaping to plain-text output.

Prefer built-in PHP functionality over additional dependencies when it meets the actual requirements. Introduce another template engine or escaping library only when a concrete requirement justifies it. Handle JavaScript, CSS, and URL contexts separately if they arise.

Start with the framework's simplest suitable option, and justify additional features against actual requirements.

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
