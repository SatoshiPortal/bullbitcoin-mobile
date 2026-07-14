# Deterministic Wallets Architecture

This feature materializes one or more wallets from a fixed BIP85 child
mnemonic. It is product-neutral: a consumer supplies a reserved index, alias,
environment, and wallet specifications through the public facade.

## Boundaries

- `public/` exposes only request/result/failure types, wallet identifiers, and
  public descriptors.
- `domain/` owns validation, idempotence, and rollback policy.
- `data/` adapts feature-domain seed material to the existing seed and wallet
  repositories.
- Consumers never receive a mnemonic, seed object, seed bytes, extended
  private key, datasource model, or repository implementation.
- Failures cross the facade as Flutter-free typed `Result` values. Diagnostic
  text is never presentation copy.

## Materialization Invariants

The fixed-index BIP85 derivation is checked against the current default Bitcoin
wallet. Repeating an identical request reuses matching wallets. A stored BIP85
path tied to a different root fingerprint is stale and is replaced with the
current root's derivation. Incompatible metadata for the current root is an
explicit conflict, never an implicit overwrite.

When materialization fails, only wallets created during that attempt are
deleted. The child seed is deleted only when that attempt stored it, no wallet
was reused, and every created wallet was deleted successfully. A cleanup
failure retains the seed and returns a rollback failure. Explicit rollback uses
the same rule.

The static BIP85 registry selects reserved indices; this feature intentionally
does not choose product reservations itself.
