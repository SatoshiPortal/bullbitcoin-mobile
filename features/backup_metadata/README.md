# Backup Metadata

`backup_metadata` owns metadata backup grouping, the local operation journal, retention and restore presentation. Its screens and catalogues live in this member; `features/backups` hosts the sections and the optional entry, and `lib/` only composes the localization delegate. The production route and background scheduling are not enabled.

Dependencies: `backup_storage` for account-bound byte sessions (Drive, Folder and iCloud), `secrets` for the foreground projection limited to eligible public Bitcoin descriptors, `labels` for transactional capture and restore with freeze checks against the exact wallet, plus `primitives` and `bull_ui`. Recomputing the physical or RecoverBull backup status is an injected capability, not a read of legacy rows.

The runtime takes an injected codec; no production codec is wired. The metadata format, item ordering and BIP-329 freeze labels are unchanged. Folder generations are recorded in a private v2 journal with a byte fingerprint, so a same-ID generation without a valid receipt never skips a write or prunes the last readable copy.
