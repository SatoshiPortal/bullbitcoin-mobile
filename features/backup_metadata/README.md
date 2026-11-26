# Backup Metadata

`backup_metadata` owns metadata backup grouping, the encrypted local journal, retention, the BIP138 codec and restore presentation. Its screens and catalogues live in this member; `features/backups` hosts the sections and the entry, and `lib/` only composes the localization delegate.

The feature is **off by default**, twice. The build must define `DATA_BACKUP=true` for the shell to compose it, mount its route under the backup settings and show its entry; the default build does none of that. Even then, nothing is written anywhere until the user turns it on and chooses a destination. It runs in the foreground only, with an unlocked inventory: after a labels change (debounced), on resume and on request (`BackupMetadataFeature.trigger`). There is no background task, because the inventory projection checks each seed's presence through `Secrets.fetch`, which a background run must never do.

Dependencies: `backup_storage` for account-bound byte sessions (Drive, Folder and iCloud), `secrets` for the foreground projection and the restore capabilities below, `labels` for transactional capture and restore with freeze checks against the exact wallet, `rust_bindings` for BIP138, plus `primitives` and `bull_ui`.

## What a file contains

One encrypted file per group: the Bitcoin and Liquid wallets of one seed on one environment, or one watch-only account. The BIP138 envelope carries three items, each with a closed list of fields:

- BIP139: the group's accounts as descriptor pairs. These are the descriptors the file is encrypted to.
- BIP329: Bitcoin labels and coin freezes (`spendable`), standard fields only.
- A Bull vendor item (`bull.metadata.v2`): Liquid labels, the wallet attribution of records, account metadata (script type, label, birthday, public descriptors) and the BIP85 registry (path, application, status, alias).

It never contains a seed, a mnemonic, a passphrase, a private key, a derived BIP85 child or a confidential Liquid descriptor. The decoder accepts nothing it did not write: version, item types, sizes, descriptors and scope are validated again on every read.

## Who can read a file

**Anyone who knows one of the group's public descriptors, including an xpub, can decrypt it.** BIP138 derives its keys from the descriptors, and there is no passphrase. The encryption protects the metadata from everyone else (the storage provider, someone who finds the file); it does not protect it from a holder of the xpub (an accountant, a watch-only service, a server given the xpub). Users are told this when they turn the feature on.

## Restore

A restore never creates a wallet and never touches a seed. The user imports the wallet first (a seed, or an xpub or descriptor through `WalletProvisioning`), then discovers and previews the backup for that wallet.

- Wallet metadata is attached only to the public wallet of the active view whose network and two descriptors equal the backup's (checksums ignored), and only where that wallet has no label or birthday yet. A wallet identifier is never a match. Signer, device and default flag are never imported. Two wallets sharing a descriptor are ambiguous: the group is neither offered nor applied.
- Labels are merged additively with a preview and per-conflict choices; freezes are checked against the exact wallet.
- The BIP85 registry is merged under the allocator's writer lock, per parent, all or nothing: every path must be canonical and consistent with its application, a conflict refuses the whole archive, gaps and revocations are kept, and a child can only become more restricted. The next index can only rise. A restore does **not** lift any recovery block.
- Discovery, preview and apply are bound to the view they started in and refuse another one. Secrets and Labels are applied in turn; both are idempotent, a failure of one is reported as a partial result, and applying again completes what is missing.

## Journal

One private encrypted database (SQLCipher raw key held by `secrets` under the module key `backup_metadata`) keeps the journal, the configured destination and each group's installation-stable id, partitioned by view: each view has its own selection, lineage and ids. Remote deletion only follows a journaled object id of the view's own lineage, so a lost or unreadable journal deletes nothing and a file name found at the destination is never trusted. Folder generations are recorded with a byte fingerprint, so a same-ID generation without a valid receipt never skips a write or prunes the last readable copy. If the key is unavailable the store refuses to open; it never falls back to an unencrypted file.

## Destinations

Google Drive (`appDataFolder`) is the only destination the app wires. iCloud and folder storages exist in `backup_storage` but need a connection store, a grant store and a container identifier that the app does not provide yet; they are not offered.

## Known follow-ups

- Group names for a default or unnamed wallet come from the English catalog, because the journal's owner builds them outside the widget tree; they should become keys resolved at render time.
- The entry's status line is static (`Off`); a live status needs a read of the journal at render time.

## Qualification

Unit and round-trip tests run against an in-memory storage and the native BIP138 library. Drive, iCloud and the folder picker have mocked-transport tests only; their native permissions, quotas and durability are **not** qualified on a device and must be tried on one before the entry is offered to users.
