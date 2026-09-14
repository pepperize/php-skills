# GitHub Actions pattern

Separate build policy from deployment mechanics. The useful boundary is the artifact that passed CI, not a second production build from the same source commit.

## Workflow shape

Use these logical jobs or workflows:

1. **Build:** check out the selected commit, validate Composer metadata, install locked development dependencies, run tests and static checks, install locked production dependencies, create an explicit archive, calculate a digest, and upload the artifact.
2. **Staging:** deploy to the target shared-hosting provider, download that artifact, verify its identity and digest, prepare a new release with the same mechanism used for production, activate it, and run the external staging smoke contract.
3. **Production promotion:** require an explicit release decision, download the same artifact that passed staging, verify it again, deploy it through the production environment, smoke-test it, and only then approve it for rollback.
4. **Rollback:** accept an exact approved release ID, share the production concurrency group, activate it atomically, and rerun the production smoke contract.

The build may be a reusable workflow so a deployment run can consume its artifact without duplicating build commands. A separate tag-driven production workflow may instead locate a successful staging run for the tagged commit and download the artifact from that exact run. In either shape, production must not run another Composer build. Tests on a GitHub runner complement hosted staging, but they do not verify the shared provider's PHP, web-server, filesystem, permission, quota, or activation behavior.

## Workflow security

- Set workflow or job `permissions` explicitly. A build normally needs `contents: read`; cross-run artifact lookup also needs `actions: read`; attestations require their documented write and OIDC permissions.
- Pin every external `uses:` dependency to a verified full commit SHA. Keep the readable release version in a comment and let Dependabot propose pin updates.
- Store production and staging credentials in their GitHub environments when the repository plan supports environment secrets. Otherwise use repository secrets with strict step scope and document that the environments do not isolate credentials. Configure environment branch or tag restrictions and required reviewers when the repository plan and operating model support them.
- Put secrets under `steps[*].env`, not workflow or job `env`. Checkout, artifact download, setup actions, and smoke tests should not inherit SSH credentials or application secrets they do not use.
- Keep the SSH host, port, public host key, deployment path, private path, and public URL in environment or repository variables. A host key is public configuration, but its value must be verified independently before commit.
- Prefer a restricted deployment key. If a shared host supports only passwords, use `sshpass` only in the deployment step, disable command tracing, and remove temporary credential files with a trap.
- Never interpolate untrusted event fields directly into shell commands. Pass them through environment variables, validate them against narrow formats, and quote every use.
- Use one concurrency group for workflows that mutate the same host boundary. Set `cancel-in-progress: false` so a newer run cannot interrupt an activation halfway through.
- Set job and command timeouts. Network retries need a finite count and should avoid replaying state-changing HTTP probes unless the probe is deliberately idempotent.

## Artifact integrity

Key the artifact by the resolved commit SHA, not a mutable branch name. Download by exact workflow run and artifact name. Include a SHA-256 manifest or use artifact attestations when the assurance and repository plan justify them, and verify before upload to the host or extraction.

The archive should contain an explicit allowlist of runtime files and production dependencies. Exclude `.env`, credentials, tests unless needed for deployment verification, local caches, development tools, VCS metadata, and mutable application data.

Inspect the archive manifest before extraction when its contents are not completely controlled by a trusted build. Reject absolute paths, parent traversal, and unexpected symbolic links.

## Environment and release decisions

An annotated or signed version tag is one possible production decision. A protected manual workflow dispatch or required environment review may fit another repository better. Build the selected event ref rather than accepting a second free-form ref input; this lets environment deployment-branch rules apply to the code and deployment scripts that receive credentials. If tags trigger production, protect matching tags against unauthorized creation, update, and deletion.

Repository files cannot prove GitHub-side environment rules, tag rulesets, secret ownership, or host permissions. Document those settings as one-time operational setup and verify them during release readiness.

## Bundled starter

The [shared-hosting example](../assets/shared-hosting-example) demonstrates a compact baseline with:

- a reusable build that produces one artifact;
- one manually initiated staging-to-production pipeline;
- step-scoped SSH secrets;
- a pinned host key and SSH-key authentication;
- immutable release directories and atomic symlink activation;
- post-activation smoke checks and production approval markers;
- rollback by an exact approved release ID.

Replace every `REPLACE_...` action reference with a verified full commit SHA before use. Adapt the archive allowlist, PHP version, environment variables, preparation block, document-root arrangement, and smoke assertions.

The starter intentionally does not delete releases or automate failed-production rollback. This keeps the generic example fail-safe. Add recovery and retention only after applying [release-model.md](release-model.md) to the project and adding the corresponding filesystem tests.

Configure these values before adapting the starter:

| Scope | Name | Purpose |
|---|---|---|
| Repository or environment variable | `SSH_HOST` | Shared-host SSH endpoint. |
| Repository or environment variable | `SSH_PORT` | Numeric SSH port. |
| Repository or environment variable | `SSH_HOST_KEY` | Independently verified `known_hosts` entry. |
| Environment variable | `DEPLOY_PATH` | Relative path under the SSH home containing `current` and `releases`. |
| Environment variable | `PRIVATE_PATH` | Separate relative private path containing the persistent `.env` and application state. |
| Environment variable | `DEPLOYMENT_URL` | HTTPS URL used by the external smoke test. |
| Environment variable | `EXPECTED_SMOKE_TEXT` | Optional public response marker that identifies the expected application. |
| Environment secret | `SSH_USERNAME` | Environment-specific deployment account. |
| Environment secret | `SSH_PRIVATE_KEY` | Restricted private deployment key. |

The starter expects the hosting control panel to point the environment's document root at `<DEPLOY_PATH>/current/public` and expects `<PRIVATE_PATH>/.env` to be provisioned separately with owner-only access. It links each release's root `.env` to that private file; adapt this if the application loads configuration through server-provided environment variables or another mechanism. Add project-specific persistent-directory links during preparation. If the provider cannot configure that document root, add a tested web-server dispatcher rather than exposing the release root.

Configure the `staging` and `production` GitHub environments with values for two deployments on the shared-hosting provider. Prefer separate hosting accounts or restricted roots. When the provider supplies one account, use distinct deployment roots, private roots, databases, credentials, and URLs, and keep the shared concurrency group because both environments still consume one physical account and quota.

The optional `bin/deploy-prepare` executable in the artifact is the project-owned pre-activation boundary. It may run runtime validation, forward migrations, and cache preparation with `APPLICATION_ENV_FILE` pointing to the private environment. It must finish successfully before activation, avoid irreversible external side effects, and be safe to retry after an interrupted candidate.

An interrupted upload or preparation may leave an incomplete release directory. The starter preserves it and fails closed; inspect its exact identity and state before manual removal. Add the recovery journal from [release-model.md](release-model.md) before automating that cleanup.
