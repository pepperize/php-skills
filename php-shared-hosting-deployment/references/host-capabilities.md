# Shared-host capability assessment

Inspect the hosting environment before selecting deployment mechanics. Provider marketing terms such as “SSH access” or “PHP 8” do not establish that the CLI and web runtime behave alike or that the filesystem supports atomic release activation.

## Capability matrix

| Capability | Why it matters | If unavailable |
|---|---|---|
| SSH command execution | Runs preflight, migrations, activation, and recovery | An upload-only FTP/SFTP workflow cannot safely reproduce the full release model. Limit the claim and use provider-supported deployment controls. |
| Independently verified SSH host key | Prevents credentials and artifacts being sent to an impersonated host | Stop until the host key can be verified through the provider console or support channel. |
| SSH key authentication | Avoids password handling in the runner | Use a provider-required password only as a step-scoped secret with strict host-key checking. |
| Bash and required utilities | Deployment scripts may need arrays, `realpath`, `tar`, `gzip`, `df`, and atomic `mv` behavior | Rewrite for the actual POSIX tools or choose a simpler provider-supported activation mechanism. |
| Symbolic links | Enables an atomic `current` release pointer | Use an atomically replaced dispatcher or a control-panel document-root switch when supported. Do not update the live tree file by file. |
| Atomic rename on one filesystem | Makes pointer or dispatcher replacement indivisible | State that zero-downtime activation is unavailable and choose an explicit maintenance-window procedure. |
| Private path outside the document root | Protects secrets, databases, uploads, locks, sessions, and logs | Use a provider-designated private directory. Web-server deny rules are a weaker fallback and must be tested externally. |
| PHP CLI matching the web runtime | Makes migration and preflight results representative | Call the provider-specific PHP binary or stop treating CLI preflight as proof of web-runtime readiness. |
| Writable persistent storage under the web identity | Allows the application to retain state across releases | Resolve ownership and permissions before deployment. Do not make the release tree broadly writable. |
| Disk and quota reporting | Prevents an upload or extraction from exhausting the account | Reserve provider-confirmed capacity and use a conservative, configurable margin. Never delete the rollback release to make room for a candidate. |
| Cross-process locking | Protects migration, state, and competing deployment operations | Serialize at the workflow level and use the strongest host-supported lock. Document remaining races with manual SSH actions. |

## Record the effective environment

Record only facts relevant to the application and deployment:

- selected PHP CLI and web versions;
- required PHP extensions;
- CLI and web user identities or confirmed permission equivalence;
- document and private roots;
- shell and utility behavior used by scripts;
- symlink and atomic-rename behavior;
- disk quota and temporary extraction capacity;
- web-server routing method and configuration propagation delay;
- log location and rotation behavior;
- backup and restore facilities;
- scheduled-task support when the application requires it.

Prefer a small authenticated diagnostic endpoint or provider control-panel evidence over a public `phpinfo()` page. Remove temporary diagnostics after recording the necessary facts.

## Safe probing

Run filesystem probes in a dedicated private test directory, never in the document root or an existing release tree. Resolve the exact path first. Test only the operations the design depends on, such as creating and atomically replacing a symlink within one filesystem. Remove the isolated probe directory after verifying its contents.

Do not assume GNU options such as `mv -T`, `/dev/fd`, process substitution, or a particular `realpath` implementation. Verify them or write the remote operation for the utilities the host actually provides.

## Isolation boundary

Run staging on the same shared-hosting provider and hosting product class as production so it exercises the same material constraints. Match the PHP runtime and extensions, web-server behavior, filesystem operations, permissions, quota model, and activation mechanism. A materially different CI container, local server, VPS, or PaaS can provide additional tests but cannot establish that the shared-host deployment works.

Separate staging and production with different SSH accounts or restricted roots when the provider supports it. Otherwise use distinct deployment roots, private roots, databases, credentials, and URLs within the account. Distinct GitHub secrets do not create host isolation when both credentials can modify the same account tree.

When environments share a hosting account or quota, use one GitHub Actions concurrency group for every workflow in that repository that mutates the shared boundary, including deployment and rollback. Concurrency groups do not coordinate separate repositories or manual SSH sessions; use a host-side lock when those can overlap. Remote validation protects against mistakes but does not replace host-side least privilege.
