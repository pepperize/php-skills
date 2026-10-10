# Deployment example differences

Read this only when adapting a layout or comparing the templates. Use `copy-examples.md` for normal setup. Both profiles reuse the working release mechanism and require the same host settings and SSH secrets.

| Concern | SQLite example | MariaDB example |
|---|---|---|
| Database prerequisite | `pdo_sqlite`, private writable database directory | `pdo_mysql`, separate hosted databases and credentials |
| Public directory | `public` | `backend/public` |
| Production root | `html/<site>` | `html/<site>` |
| Staging root | `html/<site>/staging` | `html/<site>/staging` |
| Private root | `files/<site>/<environment>` | `files/<site>/<environment>` |
| Production URL | `https://<site>/` | `https://<site>/` |
| Staging URL | `https://<site>/staging/` | `https://staging.<site>/` |
| Configuration | Host-provisioned private `.env` | Host-provisioned private `.env` |
| Application CI | Composer and temporary SQLite database | Existing Compose stack and optional compiled frontend/browser checks |
| Release fixtures | `tests/Integration/Deployment/release-retention-test.sh` plus activation tests | `deployment/tests/release-retention-test.sh` plus activation tests |

The URL style, public directory, frontend and CI setup are illustrative application choices, not consequences of the database. Adapt them only when the target differs. Changing the public directory must update dispatchers and release completeness checks consistently. Prefix staging needs application base-path support; nested subdomain document roots need Apache delegation and production-path denial.

Each `manifest.json` identifies its template and database, records file SHA-256 hashes and lists copyable versus reference-only files. This is copy-helper integrity metadata, not a deployed release journal. Maintain templates in this repository; there is no dependency on private source checkouts. After editing an asset, regenerate its manifest hashes, preserve executable modes and run that profile's fixtures and the helper tests.

Keep the existing `.pending-release` recovery record, managed-dispatcher refusal and recorded predecessor/approval state. Preserve the filesystem algorithms during adaptation. Host observations justify checking the target's capabilities and bounded worker/cache polling; they do not establish universal delays or behavior for every hosting account.
