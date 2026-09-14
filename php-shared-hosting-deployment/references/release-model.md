# Release, recovery, and retention model

Use a release tree when the host can atomically redirect traffic to a prepared directory. Adjust names to the provider, but preserve the separation between immutable code and persistent state.

```text
public-root/
|-- current -> releases/<active-release-id>
`-- releases/
    |-- <active-release-id>/
    `-- <previous-approved-release-id>/

private-root/
|-- .env
|-- application-data/
|-- uploads/
|-- locks/
|-- sessions/
`-- logs/
```

The document root should resolve to `public-root/current/public` when the control panel permits it. If the provider fixes the document root, use a small deployment-managed dispatcher that routes to `current/public` and explicitly blocks release and private paths. Refuse to overwrite an unmanaged dispatcher during first cutover.

## Candidate sequence

1. Validate local configuration, release identity, archive, SSH endpoint, and pinned host key.
2. Resolve and record the exact active release before creating the candidate.
3. Check capacity for the retained releases, uploaded archive, expanded candidate, migration or backup needs, and a configurable margin.
4. Create a new direct child of `releases`; refuse an existing, symbolic, or externally resolving target.
5. Upload the archive and verify its digest before extraction.
6. Extract into the candidate and verify its entry point, Composer autoloader, expected deployment files, and permissions.
7. Run the host-runtime preflight, forward migrations, cache preparation, and explicitly configured release hooks.
8. Atomically replace the activation pointer or dispatcher.
9. Run an external smoke test against the public URL.
10. Mark the active release approved only after smoke success.
11. Revalidate the active and predecessor identities, then apply the chosen retention policy.

Do not prune releases before the candidate is externally verified. A capacity failure must stop candidate preparation rather than delete an existing recovery option.

## Configuration and database compatibility

The code switch is atomic; the entire application state is not. Forward migrations and shared environment changes may affect the old code before or after rollback.

For every schema or configuration change, establish one of these before production:

- the old and new releases are both compatible with the resulting shared state;
- an expand-contract sequence keeps the retained predecessor usable;
- a tested backup and restore procedure will restore the matching persistent state before old code is activated;
- rollback is intentionally disabled for that release and the maintenance procedure is documented.

Do not run down migrations as an improvised rollback. Do not describe retained code as a usable rollback merely because its files still exist.

If deployment rewrites a shared `.env`, keep the old code compatible with the new keys and values. Prefer additive configuration changes, validate required values without printing them, and keep environment-specific configuration out of the artifact.

## Post-deployment hooks

A hook that sends messages, changes persisted records, warms remote services, or calls an external API is not part of the atomic code switch. Run it only at the phase where its effect is valid and document:

- whether retry is idempotent;
- whether partial completion is detectable;
- whether the predecessor remains compatible with its effects;
- whether hook failure should restore code, leave the candidate active, or require manual intervention.

Keep project-specific hooks outside the generic release primitive.

## Recovery state

For automated recovery, persist a small non-secret journal before activation. It should contain the candidate ID, captured predecessor ID, and a closed state such as `prepared`, `activation-started`, or `recovery-pending-smoke`.

On retry, inspect that journal before accepting another candidate:

- If activation never began and the predecessor is still active, the incomplete candidate may be removed after exact-identity validation.
- If the candidate is active and the predecessor is complete and compatible, atomically restore the predecessor and smoke-test it before removing the candidate.
- If the active target, predecessor, journal, approval, or compatibility state is unexpected, preserve all releases and require manual recovery.

The workflow should remain failed after an automatic recovery so the failed deployment remains visible.

## Production rollback

Accept an explicit release ID rather than “previous” or “latest.” Validate that the release:

- is a real direct child of the allowed releases directory;
- contains the expected application entry point and Composer autoloader;
- passed the production smoke gate and carries a non-symbolic approval marker;
- is not already active;
- remains compatible with persistent configuration and schema.

Atomically switch to it, run the complete external smoke test, and retain the deactivated release until the result is known. A rollback smoke failure must not trigger speculative cleanup.

## Retention

Preserving all releases is a safe initial policy when capacity is monitored. Automated bounded retention introduces destructive behavior and requires stronger proof.

For bounded retention, pass the expected active and rollback IDs into one focused operation. Before each deletion, revalidate:

- the deployment root and releases directory resolve to their allowed real paths;
- the active pointer still resolves to the expected release;
- retained releases are complete and, for production, approved;
- the deletion target is a non-symbolic direct child of `releases`;
- persistent paths are outside the deletion root;
- recovery state, when used, matches the same candidate and predecessor.

Never choose releases by modification time, directory order, or version sorting. Make repeated retention with the same identities idempotent. Report retained and removed IDs and aggregate release-tree size without reading private-state contents.

Test deletion logic against isolated temporary trees, including broken links, external links, dot-prefixed entries, unexpected files, missing markers, partial releases, changed active targets, first deployment, retry, rollback, and ambiguous recovery.
