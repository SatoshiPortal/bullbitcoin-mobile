# Data Backup

Data Backup restores public wallet inventory, labels, frozen-coin choices, portable settings and BullVault recovery policies. It does not replace a physical seed backup or a tested RecoverBull vault.

## Recovery credentials

Data Recovery Words reserve BIP85 path `m/83696968'/39'/0'/12'/100'`. This rollout assumes no mnemonic previously generated at this path was used or shared. Those words derive both encryption and server-authentication credentials; anyone holding them can access the associated data backup. The normal BIP85 mnemonic generator skips reserved indices.

Backup credentials are derived when needed. Seed words and private keys do not belong in the public keychain manifest. Readable file exports expose the included metadata and require the explicit warning shown in the app.

## Publication and recovery

Automatic publication requires consent and an active app lifecycle. Publication uses server generations and conditional writes; a different remote backup requires explicit replacement consent. A successful upload is read back before the local checkpoint is acknowledged. On startup, the publisher reconciles the server head before trusting a persisted checkpoint. Interrupted recovery remains incomplete until its remaining steps succeed, and automatic publication remains blocked during that state.

Turning Data Backup off stops automatic publication. Deleting the server copy is a separate confirmed action. Local files are an additional recovery destination, independent of server availability.

## BullVault

BullVault and signer export remain available only in super-user mode with the experimental warning. A descriptor check accepts a matching descriptor supplied by file, scan, paste, or the Copy button followed by matching clipboard readback. This confirms the descriptor matches; clipboard readback does not establish that a copy exists on another device.

Attaching a matching cosigner seed changes wallet signing capability without rewriting the original recovery descriptor or origin. Renewal carries the attached signer and its local seed reference into the successor vault.

## Release acceptance

The current endpoint is the test service at `backup.bull-wallet.com`. Production requires deployment and migration to `backup.bullbitcoin.com`, followed by authenticated upload/readback, restore, deletion, conflict and outage checks against that deployment.

Before release, exercise file pickers, clipboard verification, app background/resume, physical-seed recovery, RecoverBull key viewing and hardware BullVault create/renew/recovery on supported devices. Preserve upgrades from the latest published database schema and consolidate unreleased schema changes into the one pending revision. Standalone passphrase wallets, Nostr-hosted storage and OP_RETURN storage are outside this feature.
