---
name: php-shared-hosting-deployment
description: Creates or reviews PHP shared-hosting deployments using tested SQLite or MariaDB pipeline examples. Activate only when root AGENTS.md explicitly contains the shared-hosting marker and exactly one SQLite or MariaDB database marker. Use for SSH-accessible shared hosting.
---

# PHP Shared Hosting Deployment

## Activation Guard

Before applying this skill, read the project's root `AGENTS.md`. Apply it only when that file contains the standalone marker `<!-- php-skills:hosting:shared -->` and exactly one of `<!-- php-skills:database:sqlite -->` or `<!-- php-skills:database:mariadb -->`. Count actual standalone comments outside fenced examples, not mentions in prose, quoted templates or this skill's instructions.

Use only the example selected by the database marker. Missing root `AGENTS.md`, a missing marker, an unsupported database or conflicting database markers keeps this skill inactive, even if workflows or dependencies suggest shared hosting. Explain the missing profile briefly. The `php-agent-instructions` skill records user-confirmed answers; do not add markers merely to activate this skill. Markers authorize use of guidance, not host provisioning or live deployment.

## Reuse a Working Pipeline

- SQLite: [sqlite-example](assets/sqlite-example/.github/workflows/deploy-staging.yml).
- MariaDB: [mariadb-example](assets/mariadb-example/.github/workflows/deploy-staging.yml).
- Read [copy-examples.md](references/copy-examples.md), then use `scripts/copy-pipeline.py --database sqlite --site example.com --target <project-directory>` with the marked database and actual site. Use `--dry-run` to inspect destinations. The helper verifies template hashes, preserves executable modes and refuses existing files.
- Preserve the tested release, recovery, approval, rollback and retention scripts. Adapt the site, host settings and project-owned build, prepare and smoke checks. Do not regenerate the deployment engine or introduce a configuration framework for ordinary setup.
- Both examples use `html/<site>` and `html/<site>/staging`, with private state under `files/<site>/production` and `files/<site>/staging`. Both use environment-scoped `SSH_USERNAME` and `SSH_PASSWORD`. Keep these conventions unless the target has a demonstrated difference.
- For an existing pipeline, copy into a temporary directory and merge only the required changes. Read [project-contract.md](references/project-contract.md) for settings and database preparation, or [example-comparison.md](references/example-comparison.md) for layout differences. Frontend tooling, public-directory layout and staging URL style are independent of the database.

## Scope

Use this skill when creating or reviewing deployment automation for a PHP application on shared hosting with SSH access. Treat the hosting account as a constrained server: capabilities, filesystem layout, storage quota, PHP CLI behavior, and web-server control vary by provider.

Creating or changing a workflow does not authorize running a live deployment. Trigger staging or production only when the user requests that external action.

## Inspect Before Designing

Read the project instructions, existing workflows, deployment scripts, application startup, migration system, and operational documentation. Establish the host capabilities before selecting an activation mechanism. For a new host or an uncertain environment, read [host-capabilities.md](references/host-capabilities.md).

Identify these boundaries explicitly:

- the document root and whether it can point to `current/public`;
- a private persistent root for environment configuration, uploads, databases, locks, sessions, caches, and logs;
- the SSH authentication methods and independently verified host key;
- PHP CLI and web-runtime versions, extensions, identity, and filesystem permissions;
- support for Bash, archives, symbolic links, atomic rename, locking, and disk-usage commands;
- the migration, configuration-compatibility, backup, smoke-test, and rollback policies.

Do not copy a symlink, Apache, password-authentication, or SQLite design onto a host that does not support or require it. State the limitation when the host cannot provide a safe activation boundary.

## Required Deployment Invariants

- Build and test one production-dependency artifact. Promote that exact artifact through staging and production instead of rebuilding it for production.
- Deploy both staging and production to the target shared-hosting provider with the same release mechanism. Staging must exercise the provider's real PHP runtime, web-server routing, filesystem behavior, permissions, and activation boundary; a CI runner or unrelated hosting platform is not a substitute for hosted staging.
- Record the source commit and verify the downloaded artifact with a digest or provenance mechanism appropriate to the project.
- Grant the GitHub token only the permissions each workflow needs. Pin external actions to full commit SHAs and use a maintained update mechanism such as Dependabot. Never invent a commit SHA; when a verified SHA is not supplied or cannot be checked, use an explicit placeholder and state that it must be replaced with an independently verified value.
- Prefer environment-scoped secrets when the repository plan supports them, and expose each secret only to the step that needs it. If only repository secrets are available, retain step scope and document the weaker environment boundary. Keep non-sensitive host configuration in `vars` or ordinary workflow configuration.
- Pin the SSH host key from an independently verified source. Prefer SSH keys; use password authentication only when the provider requires it and keep the password step-scoped.
- Validate deployment paths, release identifiers, hostnames, ports, and remote reports before using them in shell commands or filesystem mutations.
- Put each release in a new directory. Never update the active release in place.
- Keep persistent state outside release directories and outside the document root. A code rollback must not replace or delete persistent state.
- Run host-runtime preflight and forward migrations before activation. Treat shared configuration and schema changes as compatibility concerns for both the old and new code.
- Activate through one atomic boundary, normally a `current` symlink or an atomically replaced dispatcher supported by the host.
- Run an external smoke test after activation. Approve the release for rollback and prune older releases only after that smoke test passes.
- Select rollback and retention targets by recorded release identity. Do not infer them from timestamps, semantic versions, lexicographic order, or directory enumeration.
- Revalidate the active target, path containment, release completeness, and approval state immediately before activation or deletion. Preserve every release when the state is missing, changed, or ambiguous.
- Serialize workflows around the physical shared resource, not merely the logical environment, when staging and production share an account, storage quota, database, or document root. Set finite job and network timeouts.
- Isolate staging and production with separate hosting accounts or restricted roots when possible. At minimum, give them separate deployment roots, private state, databases, credentials, and public URLs.

Read [release-model.md](references/release-model.md) before implementing activation, rollback, recovery, database migration, or retention behavior.

## Project Decisions

Keep these choices explicit instead of baking them into the generic pattern:

- automatic or manual production rollback after a failed smoke gate;
- SSH key or provider-required password authentication;
- control-panel document-root configuration, Apache rewrite dispatch, or another web-server adapter;
- release count, capacity margin, and cleanup schedule;
- database backup creation, restoration, and expand-contract migration rules;
- whether configuration is provisioned once on the host or delivered during deployment;
- application-specific post-deployment hooks and their idempotency and rollback behavior;
- smoke-test routes, harmless probes, expected status codes, and environment-specific acceptance checks.

Automatic production rollback is safe only when the captured predecessor is known-good and both database and shared configuration remain compatible. Otherwise preserve the candidate and predecessor, report the exact state, and require an operator decision.

## GitHub Actions And Example

Read [github-actions.md](references/github-actions.md) when creating or reviewing workflows. It explains workflow separation, environment controls, secret scope, action pinning, artifact verification, and the bundled starter.

Use the selected SQLite or MariaDB example for a complete pipeline with tested recovery and retention. The files under [assets/shared-hosting-example](assets/shared-hosting-example) remain a smaller illustrative starter for hosts whose control panel can point directly at `current/public`. It has different authentication and activation assumptions; select it only when those fit the target. Adapt every `REPLACE_...` value and the archive manifest, preparation commands, document-root arrangement, and smoke contract. This minimal starter deliberately preserves release directories.

## Verification

Before finalizing a deployment change:

- validate workflow syntax with `actionlint` or an equivalent parser;
- run `shellcheck` and `bash -n` for Bash scripts;
- exercise release preparation, activation, interrupted deployment, rollback, and retention against temporary filesystem fixtures;
- verify that tests cover symlinks, broken links, path traversal, unexpected files, invalid reports, missing approvals, insufficient capacity, and idempotent retry;
- verify that logs and workflow summaries contain release identities and phases without secrets or private data;
- run the application test suite and build the same production artifact the workflow will upload;
- rehearse staging on the real host before enabling production, recording only non-sensitive operational evidence.

Do not claim zero downtime, atomic rollback, or bounded retention unless the selected host behavior and tests establish those properties.
