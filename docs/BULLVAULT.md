# BullVault

BullVault is a Bitcoin descriptor wallet with multiple signing keys and scheduled
recovery paths. Create it from **Settings → Create BullVault**. Existing vaults
appear in the wallet list; their own settings provide setup, recovery data, and
renewal actions.

## Keys and default schedules

`M` is the everyday key (Bull's mobile key by default), `C` is a separately stored
cold key, and `I` is an optional inheritance key. Extra protection adds `C2`.
The everyday key can instead come from a supported hardware signer. Inheritance
can use a hardware key, a compatible public account key, or a separately backed-up
mnemonic. Keep these keys and their backups independent.

| Setup | Available immediately | Additional recovery paths |
| --- | --- | --- |
| Standard | M + C | C alone after 2 years; M alone after 3 years |
| Standard with inheritance | M + C | Any two of M/C/I after 2 years; C alone after 3 years; I alone after 5 years |
| Extra protection | Any two of M/C/C2 | Either cold key alone after 3 years; M alone after 5 years |
| Extra protection with inheritance | Any two of M/C/C2 | I with any owner key after 2 years; I alone after 5 years; no owner key can spend alone |

Recovery delays are adjustable from 1 to 10, with the required ordering enforced
for each profile. Practice mode uses the same numbers as **hours**, not years.
Practice wallets are labelled in the app and are unsuitable for long-term storage.

The descriptor commits to fixed activation timestamps, not delays that restart
with each deposit. Dates are derived from phone time, checked against Bitcoin
median time past (at most 24 hours apart); stale reviews must refresh their time
reference. The app shows exact UTC dates alongside the chosen delays. Bitcoin
chain time determines when the transaction is eligible, so a displayed date is
not a guarantee of immediate confirmation. Timelocked spends use non-final
input sequences.

## Hardware setup and backups

BullVault account keys use `m/48'/coin_type'/account'/2'`. Bull's mobile account
allocator is shared with **Use Bull as signer**: manual exports are suggestions
until explicitly marked used; successful creation/import reserves the actual
verified account. Used accounts are not released when a wallet is deleted.

Hardware choices come from the shared complex-Taproot capability list: supported
Ledger models, BitBox02, Krux, and Specter. Firmware, connection, policy, and key
ownership checks still apply. A device's support for ordinary multisig alone does
not establish BullVault support.

Setup requires successful policy registration for connected devices. Air-gapped
devices use the registration/export flow and explicit confirmation. Address
verification is available on **Receive**, with a reminder to verify on the
hardware wallet before depositing; it is not an onboarding completion condition.
Explicitly deferred hardware or mobile-backup setup remains incomplete and can be
completed from the vault's settings.

Bull's physical mnemonic backup and tested RecoverBull backup protect the same
mobile seed. Verification is checked for that exact seed, including previously
verified backups; it must not transfer between different local cosigners.
RecoverBull setup is optional and requires the user's own recovery choices.
Neither method backs up cold/inheritance keys or the vault descriptor. **Saving
and confirming the separate BullVault recovery package is always required.**

### Mobile passphrase

An optional BIP39 passphrase protects the everyday mobile key. BullVault does not
store this passphrase and asks for it when the selected signing path requires it.
Bull cannot recover a lost passphrase.

Optional **Delayed mobile recovery** uses the same mnemonic without that
passphrase for the scheduled mobile recovery paths. This recovery key and the
protected everyday key share one logical signer and one account reservation;
they are never two independent votes in a threshold. Their different xpubs have
independent branch allocations.

Restoration checks mobile ownership cryptographically against stored seeds. With
the correct passphrase, Bull verifies the protected key. Without it, a matching
passphrase-free recovery key permits recovery-only restoration. Otherwise the
descriptor can be restored with mobile signing unavailable until verification.

## Recovery package and restoration

The public JSON file contains no private keys. It carries `schemaVersion`,
`policyVersion`, `network`, the canonical `descriptor`, and `lineageId`, with
optional `birthHeight`, `createdAt`, `schedule`, and `previousVaultId` metadata.
`schedule` stores its unit (`years` or `hours`) and the applicable `cold`,
`recovery`, and `inheritance` values. The complete version-1 example lives in
[the recovery fixture](../test/features/bullvault/data/fixtures/bullvault_recovery_v1.json).

The descriptor is authoritative for scripts, keys, roles, thresholds, branch
pairs, and activation times. Optional schedule metadata must agree with those
times and the creation date. Network and template/version checks are mandatory.
Database wallet IDs and hardware assignments are not portable recovery data.

Restore using the recovery file, or paste/scan a supported BullVault descriptor.
An existing wallet is matched by descriptor identity rather than its old database
ID. Descriptor-only restoration leaves unknown original relative delays unknown;
renewal offers defaults to review instead of inventing the old schedule. A later
compatible recovery package can enrich that restored wallet's metadata.
Hardware devices must be assigned and registered again.

A renewed package cannot be restored as a second active member beside its active
predecessor. Descriptor-first restoration followed by compatible package
enrichment can reconcile the predecessor link. Restoration validates lineage;
it does not infer an arbitrary family relationship from similar descriptors.

## Renewal

Renewal creates a replacement descriptor with new dates and the same keys. It is
not key rotation: compromised keys require new keys and a transfer to a new vault.
The user confirms starting renewal and the need to register the replacement on
the hardware devices, reviews the schedule, saves its recovery package, and
registers it before activation. Setup can be left and resumed later, but all
hardware keys must be registered before the renewed vault can be activated.

Each xpub advances only by the branch pairs it actually uses. For example, a key
using `<0;1>` and `<2;3>` next uses `<4;5>` and `<6;7>`. Allocation is per xpub,
not per spending path; different xpubs may use the same numeric pair. Unsuccessful
preparation releases an unused generation; saved replacements retain their pairs.

Activation changes which vault receives new deposits. It does **not** change old
UTXOs or automatically renew their locks: funds must be moved through the normal
review/sign/broadcast flow to the successor. Old generations stay monitored for
remaining funds and late deposits.

A pending renewal can be cancelled before activation. Cancellation leaves the
current vault active and marks the replacement cancelled rather than deleting
its exposed addresses. Cancelled replacements with funds are surfaced for
recovery; their branches are not reused. Durable pending/activating/migrating
states support retry after interrupted persistence or app restarts.

## Maintainer boundaries

BullVault owns its policies, recovery encoding, lifecycle repository, use cases,
and UI. Other features are accessed through public facades and BullVault-owned
use cases; wallet signing verifies the actual descriptor/transaction at its
shared boundary. See [FEATURES.md](../FEATURES.md) for the dependency graph.

Changes to safety-critical recovery, passphrase, signing, and lifecycle copy need
reviewed translations for supported release locales. Analyzer and test success do
not establish translation completeness.
