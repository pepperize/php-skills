---
name: php-templating
description: Applies company PHP templating conventions for engine selection, layouts, partials, output escaping, and translation. Use when choosing or changing a PHP template engine, writing or reviewing PHP templates, or implementing template escaping and translation helpers.
---

# PHP Templating

## Template Engine And Escaping

For Slim-based projects, prefer `slim/php-view` with native PHP templates, using its layouts and partials for reuse. Templates must support direct step-by-step debugging with Xdebug without template compilation.

When using `slim/php-view`:

- Configure the layout on the renderer with `$renderer->setLayout('layout.php')`.
- Render reusable template parts with `$this->fetch('partials/contact.php', ['name' => $name])` so their input is explicit.
- Do not use APIs from other template engines such as `$this->layout()`, or bypass PHP-View's partial support with raw `include` calls.

Escape HTML output explicitly through a shared `html(string $value): string` helper using `htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8')`. Do not apply HTML escaping to plain-text output.

Prefer built-in PHP functionality over additional dependencies when it meets the actual requirements. Introduce another template engine or escaping library only when a concrete requirement justifies it. Handle JavaScript, CSS, and URL contexts separately if they arise.

Start with the framework's simplest suitable option, and justify additional features against actual requirements.

## Translation In Templates

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
