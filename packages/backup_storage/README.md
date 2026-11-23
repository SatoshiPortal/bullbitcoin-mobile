# Backup storage

`backup_storage` stores bytes through an account-bound `StorageSession`. Callers own serialization, encryption, file naming, upload reconciliation and retention. The package does not interpret vaults or other backup formats.

`GoogleDriveBackupStorage` uses the `google_drive` package's shared Google Sign-In owner and Drive's `appDataFolder` scope. Noninteractive authorization never permits token-recovery UI. Every authorization and session operation has a fixed 60-second deadline. A changed account invalidates a session; acquire a new session explicitly instead of following the new account. Drive account IDs currently use the email identity required by RecoverBull and must never be logged.

Drive listing exhausts pagination, matches MIME and an optional literal name prefix, and returns size, timestamps and MD5 metadata. Reads enforce the caller's byte cap on both metadata and streamed bytes. Successful Drive creates are `durable`; callers must reconcile ambiguous uploads by their own unique name and bounded read-back before acknowledging or pruning. Disposal releases transports and listeners without revoking authorization. Only `disconnect` revokes the grant.

The reusable suite in `test/support/storage_contract.dart` runs against the in-memory backend, Drive with mocked HTTP, and Folder and iCloud with mocked platform channels. It does not qualify native permissions, scheduling, or platform durability.
