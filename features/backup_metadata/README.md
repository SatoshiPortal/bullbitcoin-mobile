# Backup Metadata

`backup_metadata` owns metadata backup grouping, the encrypted local journal, retention, the BIP138 codec and restore presentation. Its screens and catalogues live in this member; `features/backups` hosts the sections and the entry, and `lib/` only composes the localization delegate.

The feature is **off by default** and the setting is persistent: it is the selection (a destination, an account and wallets) the user confirmed, kept in the member's encrypted journal, per view. Until then nothing is read from a destination, created there or sent. The app always composes the member; the settings entry and its route are always present, and their status line reads the journal (off, or on with the last durable backup). It runs in the foreground only, with an unlocked inventory: after a labels change (debounced), on resume and on request (`BackupMetadataFeature.trigger`, which does nothing before the journal exists). There is no background task, because the inventory projection checks each seed's presence through `Secrets.fetch`, which a background run must never do.

Dependencies: `backup_storage` for account-bound byte sessions (Drive, Folder and iCloud), `secrets` for the foreground projection and the restore capabilities below, `labels` for transactional capture and restore with freeze checks against the exact wallet, `rust_bindings` for BIP138, plus `primitives` and `bull_ui`.

## What a file contains

One encrypted file per group: the Bitcoin and Liquid wallets of one seed on one environment, or one watch-only account. The BIP138 envelope carries three items, each with a closed list of fields:

- BIP139: the group's accounts as descriptor pairs. These are the descriptors the file is encrypted to.
- BIP329: Bitcoin labels and coin freezes (`spendable`), standard fields only.
- A Bull vendor item (`bull.metadata.v2`): Liquid labels, the wallet attribution of records, account metadata (script type, label, birthday, public descriptors) and the BIP85 registry (path, application, status, alias).

The engine never reads a seed, a mnemonic, a passphrase, a private key, a derived BIP85 child or a confidential Liquid descriptor to serialize it: none of them is a field of the format. Free text typed by the user (labels, wallet names, aliases, references) is a separate matter: it is filtered on a best-effort basis (see Secret-shaped text), so a phrase hidden in a note is caught only in the forms listed there. The decoder accepts nothing it did not write: version, item types, sizes, descriptors and scope are validated again on every read.

## Who can read a file

**Anyone who knows one of the group's public descriptors, including an xpub, can decrypt it.** BIP138 derives its keys from the descriptors, and there is no passphrase. The encryption protects the metadata from everyone else (the storage provider, someone who finds the file); it does not protect it from a holder of the xpub (an accountant, a watch-only service, a server given the xpub). Users are told this when they turn the feature on.

## Restore

Restore is reachable from the first screen of the journey, on a phone that never turned the feature on: it reads a destination (the discovery never persists a choice) and writes only what the user previews and applies. It never creates a wallet and never touches a seed. The user imports the wallet first (a seed, or an xpub or descriptor through `WalletProvisioning`), then discovers and previews the backup for that wallet.

- Wallet metadata is attached only to the public wallet of the active view whose network and two descriptors equal the backup's (checksums ignored), and only where that wallet has no label or birthday yet. A wallet identifier is never a match. Signer, device and default flag are never imported. Two wallets sharing a descriptor are ambiguous: the group is neither offered nor applied.
- Labels are merged additively with a preview and per-conflict choices; freezes are checked against the exact wallet.
- The BIP85 registry is merged under the allocator's writer lock, per parent, all or nothing: every path must be canonical and consistent with its application, a conflict refuses the whole archive, gaps and revocations are kept, and a child can only become more restricted. The next index can only rise. A restore does **not** lift any recovery block.
- A file belongs to a group only when **every** public descriptor of the group equals one of the file's, checksums aside; sharing one key is not a match. The wallet identifiers a file carries are rewritten to this phone's identifiers by matching the public descriptors, so a freeze or a label follows the wallet that was re-imported under another id.
- Discovery, preview and apply are bound to the session they started in and refuse any other one, including the same view reopened after a lock. Secrets and Labels are applied in turn; both are idempotent, a failure of one is reported as a partial result, and applying again completes what is missing.

## Session and revocation

`BackupSessionRef` carries the durable view identifier and whether the authority still holds the exact session generation it was issued in. A lock ends it for good; reopening the same view is a new generation. Every effect asks `isCurrent` synchronously, immediately before it starts: the journal write and the upload after encryption, each deletion, the delivery of a discovery, of a preview and of its emission by the cubit, and each owner's write. Secrets writes also run in guarded transactions and roll back if the session ends before their commit. A write an owner has already admitted (a Labels transaction in progress) completes in that owner's own transaction.

## Shared keys

Secrets decides whether a wallet is the only holder of its BIP138 recipient keys, from the real memberships and the keys themselves, not from descriptor text. A recipient key is the x-only public key of an extended public key in the descriptor, the way the BIP138 binding extracts it, so a different script, a different derivation or a different checksum does not hide a shared key. A wallet is exclusive only if its row is visible in no other view (`wallet:<id>` and `secret:<fingerprint>` memberships) and none of its keys is carried by another wallet, on any network and in any view. Secrets answers only about the wallets of the calling view and never returns anything of another one. A group with a wallet that is not exclusive, or that Secrets did not name, is reported with a dedicated reason and is never captured, published, offered for restore or applied.

## Account changes

The account behind the destination is recorded when the user confirms it. If the grant later resolves to another account, nothing is sent and the status asks the user to reconnect, which goes through the same confirmation again.

## Recovery blocks (D94, D101)

This base has no recovery block on a BIP85 parent. The registry merge therefore lifts nothing and authorizes no child: it only adds records and makes existing ones more restricted, so the next index can only rise. When the block lands, a parent that is blocked must stay blocked after a restore of an older archive; that requires the block to be a separate state the merge does not touch, and a test on the day it exists.

## Secret-shaped text

Free-text fields (label records, wallet names, BIP85 aliases) are checked before anything is prepared, and again on everything read back, by a pure detector: a run of at least twelve consecutive words that all belong to one of the ten BIP39 word lists (Unicode segmentation, NFKD, any case, ideographic space included), a whole segment of 12, 15, 18, 21 or 24 contiguous Chinese characters that forms a checksum-valid BIP39 phrase in either Chinese list, an extended private key or a WIF key. Best effort: a phrase that is split, abbreviated or mixed with other words in ordinary text can escape it, and a Chinese phrase glued to other characters without punctuation is not detected. Ordinary Chinese text can also happen to have a valid BIP39 checksum and be excluded; the checksum reduces false positives but cannot eliminate them. A record whose reference matches is left out whole, a freeze included. A label record whose text matches is left out (a frozen coin keeps its freeze and loses its text); a wallet name or an alias is blanked, because dropping the entry would drop an account from the descriptor set or a child from the registry, whose index could then be allocated again. The status and the restore result show how many were left out, in English and French, never what they said. The writer refuses content that was not checked.

## Journal

One private encrypted database (SQLCipher raw key held by `secrets` under the module key `backup_metadata`) keeps the journal, the configured destination and each group's installation-stable id, partitioned by view: each view has its own selection, lineage and ids. Remote deletion only follows a journaled object id of the view's own lineage, so a lost or unreadable journal deletes nothing and a file name found at the destination is never trusted. Folder generations are recorded with a byte fingerprint, so a same-ID generation without a valid receipt never skips a write or prunes the last readable copy. If the key is unavailable the store refuses to open; it never falls back to an unencrypted file.

## Destinations

Google Drive (`appDataFolder`) is the only destination the app wires. iCloud and folder storages exist in `backup_storage` but need a connection store, a grant store and a container identifier that the app does not provide yet; they are not offered.

## Known follow-ups

- Group names for a default or unnamed wallet come from the English catalog, because the journal's owner builds them outside the widget tree; they should become keys resolved at render time.

## Qualification

Unit and round-trip tests run against an in-memory storage and the native BIP138 library. Drive, iCloud and the folder picker have mocked-transport tests only; their native permissions, quotas and durability are **not** qualified on a device and must be tried on one before the entry is offered to users.
