# Shared-hosting settings and database preparation

Keep ordinary setup small. The examples already implement release, recovery, rollback and retention; reuse them rather than introducing a new deployment framework or configuration parser.

## Directory and secret conventions

Use `--site` when copying to replace the sample hostname consistently. Both profiles use:

| Setting | Convention |
|---|---|
| Production deployment root | `html/<site>` relative to SSH home |
| Staging deployment root | `html/<site>/staging` relative to SSH home |
| Private production root | `files/<site>/production` relative to SSH home |
| Private staging root | `files/<site>/staging` relative to SSH home |
| Private configuration | `.env` under the environment's private root, mode `0600` |
| Releases | Direct children of `<deployment-root>/releases` |
| Activation | Atomic replacement of `<deployment-root>/current`, with the managed Apache dispatcher |
| GitHub environments | `staging` and `production` |
| Environment secrets | `SSH_USERNAME`, `SSH_PASSWORD` |
| GitHub variables | `SSH_HOST`, independently verified `SSH_HOST_KEY`, `EXPECTED_SMOKE_TEXT` |
| SSH port | `22`; change consistently if the account requires another port |
| Runtime | PHP `8.4` in the examples; verify the actual CLI and web runtime |
| Artifact | `application.tar.gz`, named `application-<commit>` in GitHub |
| Retention | Active release and recorded predecessor, after public smoke passes |

The host name and host key belong to the hosting account and are not inferred from the site. Keep the existing password-based transport for these examples; change authentication only when supported and needed by the target. Provision application credentials privately once. Normal releases require the existing `.env` and never replace it.

The examples use explicit validated environment-root checks. Keep those checks aligned with the workflow values when an actual host requires other paths. Preserve private-state containment, environment separation, safe relative paths, direct-child release checks and capacity margins. GitHub concurrency covers one repository; shared accounts spanning repositories need existing host coordination across deployment, public smoke and retention.

## Database profiles

SQLite requires `pdo_sqlite` and a private environment-specific `application` directory writable by the PHP runtime, normally mode `0700`. Configure the application's existing database-path setting in the private `.env` to `<private-root>/application/application.sqlite`. Preserve existing files and support journal/WAL/SHM creation and host locking; never package a local database or create a new database per release.

MariaDB requires `pdo_mysql` and separate staging/production databases and credentials. Provision databases once and use the application's existing connection settings, such as `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER` and `DB_PASSWORD`. Preparation verifies the application's existing migration/status commands; database credentials stay outside the archive.

Both profiles run forward migrations before activation and check the production Composer/platform requirements. A code rollback keeps the live database and private configuration. Preserve predecessor compatibility or follow the application's established restore procedure; code rollback does not run down migrations or restore persistent state.

## Application-owned entry points

Keep an existing project's working equivalents when adapting its pipeline. The templates provide `deployment/build.sh OUTPUT_DIRECTORY`, `deployment/prepare.sh` and `deployment/check-deployment.sh HTTPS_URL` as small editable application boundaries. Build owns runtime assembly; prepare owns configuration, database prerequisites and migrations; smoke owns harmless public application acceptance. Preparation receives `APPLICATION_ENV_FILE`, the absolute `PRIVATE_PATH`, `DEPLOYMENT_NAME`, `RELEASE_ID` and `PHP_BIN`.

Keep SMTP checks, user onboarding, business messages, legacy-storage movement and release-readiness policy in the application when required. They are not hosting or database prerequisites. The examples preserve exact release identity on recovery/rollback; newly promoted artifacts also carry and verify the tested source commit. Adapt browser/source acceptance to the application's actual rendered metadata.
