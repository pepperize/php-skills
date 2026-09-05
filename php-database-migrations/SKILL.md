---
name: php-database-migrations
description: Applies company database migration conventions for PHP projects. Use when adding, reviewing, or deciding whether to create database migrations, especially selecting the application's existing migration system, naming migrations, and preserving applied migration integrity.
---

# PHP Database Migrations

## Creation Rule

Do not add database migrations unless they are explicitly needed by the requested change or explicitly requested by the user.

If a schema change is implied but not clearly required, ask before adding a migration.

## Migration System

Use the migration system provided by the application framework or already established by the project.

- Prefer Laravel migrations for Laravel applications.
- Prefer Doctrine Migrations for Doctrine or Symfony applications.
- Prefer Phinx for other PHP applications that do not already have a migration system.
- Do not introduce an additional migration framework when the project already has one.

## Version Naming

Use the timestamp-based naming generated or expected by the selected migration system.

Examples include:

- Laravel: `2026_04_14_182900_add_short_description_to_products_table.php`
- Doctrine Migrations: `Version20260414182900.php`
- Phinx: `20260414182900_add_short_description_to_products.php`

Do not replace the selected system's timestamp convention with sequential versions.

## Scope

Keep each migration focused on the schema or data transition required for the change.

Avoid bundling unrelated cleanup or opportunistic schema edits into the same migration.

## Applied Migration Integrity

Do not edit already-applied migrations to change schema behavior. Add a new timestamped migration using the project's existing migration system instead.

After adding or changing migrations, run the project-documented migration validation or status command and verify a real application startup or equivalent framework boot path that exercises migration configuration.

If the migration system reports a metadata, version, or checksum mismatch, do not blindly mark, synchronize, or repair it. First inspect the live schema. Metadata repair is acceptable only when the schema already matches the current migration files and the issue is local metadata drift.
