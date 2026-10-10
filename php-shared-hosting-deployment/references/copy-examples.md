# Copy and adapt a deployment example

First check the activation markers in root `AGENTS.md` as described in `SKILL.md`. Select only the marked database profile.

| Example | Representative application | Included |
|---|---|---|
| `assets/sqlite-example/` | SQLite, server-rendered PHP, `public`, staging URL prefix | Four workflows, release/recovery/rollback/retention scripts, Apache dispatchers and filesystem/activation fixtures |
| `assets/mariadb-example/` | MariaDB, `backend/public`, compiled frontend, staging subdomain | The same release operations plus Compose CI, optional browser smoke tooling and fixtures |

Database choice does not require a particular frontend, source layout or staging URL style. Preserve the application's existing choices. These are maintained deployment templates, not complete applications. They contain no application source, live `.env`, dependencies or databases. The frontend package files are reference-only; merge browser tooling into an existing project rather than replacing its dependencies.

## Copy once

Resolve the helper from the loaded skill directory. For the usual local installation:

```bash
python3 "$HOME/.agents/skills/php-shared-hosting-deployment/scripts/copy-pipeline.py" \
  --database mariadb --site example.com --target "$PWD" --dry-run
```

Use the marked database and actual lowercase site hostname. Omit `--dry-run` to copy. The helper verifies template hashes, substitutes the site consistently (including escaped Apache host patterns), preserves executable modes and checks every destination before writing. Existing files, symlinked destination directories and file/directory collisions stop the copy. For an established project, copy to a temporary directory and merge only needed changes.

## Configure the host and application

Both examples use the directory and secret conventions in [project-contract.md](project-contract.md). Keep them unless the existing host requires a change. Set `SSH_HOST`, an independently verified `SSH_HOST_KEY` and `EXPECTED_SMOKE_TEXT` as GitHub variables. Set `SSH_USERNAME` and `SSH_PASSWORD` in each GitHub environment. Provision the private `.env` once; releases do not rewrite it.

Adapt these project-owned boundaries:

- `deployment/build.sh OUTPUT_DIRECTORY`: assemble the explicit runtime allowlist using the existing application layout. The workflow runs the project's CI and production dependency installation, then adds `source-commit` and archives this output. Keep secrets, databases and other mutable state out of it.
- `deployment/prepare.sh`: validate private configuration and run the existing forward migration commands before activation. The SQLite example also provisions the private database directory. Adapt the illustrated Doctrine commands to the target's existing migration tool.
- `deployment/check-deployment.sh`: supply the application's harmless health and page checks. Its illustrative health JSON expects `status`, `release` and `php`; adapt the application's actual response while retaining release identity verification, finite retries and private-path denial. The compiled frontend/browser example is optional and independent of MariaDB.

The SQLite build illustrates conventional PHP source directories and Composer commands. The MariaDB build illustrates an existing Compose `db`/`mailpit`/`app` stack and frontend build; adapt those application-owned steps to the target. The SQLite PHP setup action is pinned to the verified [2.37.2 release commit](https://github.com/shivammathur/setup-php/commit/f3e473d116dcccaddc5834248c87452386958240). Keep verified existing action pins and use Dependabot to maintain them.

Retain the tested release sequence: candidate capacity, artifact/source verification, private preparation, atomic code switch, public smoke, approval and identity-based retention. Production promotes the exact successful staging artifact. Annotated version-tag and ancestry checks remain. Do not regenerate the release engine or add project-specific readiness tickets, legal approvals, onboarding, SMTP checks or historical Apache rules to the templates.

## Validate locally

Run from the selected example or copied project root:

```bash
# SQLite example:
bash tests/Integration/Deployment/release-retention-test.sh
python3 -B -m unittest discover -s deployment/tests

# MariaDB example:
bash deployment/tests/release-retention-test.sh
python3 -B -m unittest discover -s deployment/tests
```

The fixtures use temporary hosting trees without live hosting or application dependencies. After adaptation, validate workflow syntax, check Bash scripts and run the target's actual CI/build. Live smoke and release operations require the user's existing authorization for that external action.
