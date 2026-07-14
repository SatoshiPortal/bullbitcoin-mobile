# Backup health reminders

Backup health reminders encourage users to periodically confirm that their wallet can still be recovered. They supplement the existing no-backup warning; they do not replace it.

## Reminder matrix

The reminder is evaluated for the default mainnet hot-wallet seed after at least one backup method has been verified. Eligible balances are aggregated separately as described below.

| Verified backup posture | Reminder message | Primary action | Secondary action |
| --- | --- | --- | --- |
| No verified backup | No quarterly reminder. Existing no-backup warning behavior remains unchanged. | Existing backup flow | Existing dismissal behavior |
| Recoverbull only | Explain that automatic recovery normally depends on the Recoverbull key server and recommend an independent physical backup. | Create and test a physical backup | Acknowledge the dependency risk |
| Physical only | Ask the user to perform a health check of the physical backup they already have. Recoverbull is available only through a neutral link to other backup options. | Test the physical backup | Remind in three months |
| Recoverbull and physical | Ask the user to review and test their available backups. | Review backup options | Remind in three months |

The reminder is shown only on the wallet home screen and only after higher-priority no-backup and legacy-storage warnings are clear.

## Timing and balance milestones

A scheduled reminder becomes due 90 full days after the most recent of:

- the latest completed physical backup;
- the latest completed Recoverbull backup; or
- the last time the user acknowledged the reminder.

A verified backup record with no completion timestamp is treated as due immediately. Acknowledging a reminder starts a new 90-day interval.

Balance milestones can show the reminder before the scheduled date:

- more than 1,000,000 sats; and
- more than 10,000,000 sats after the first milestone has been handled.

The comparisons are strict: exactly 1,000,000 or 10,000,000 sats does not trigger a milestone. Each milestone is recorded after the user acknowledges the reminder or completes the selected backup action, so ordinary balance fluctuations do not repeatedly trigger it.

Starting a backup action records a pending action. On the next evaluation, a backup completion timestamp at or after the action start handles the associated balance milestone. Cancelling the flow leaves the milestone due for the next app session.

## Eligible wallets and balances

Only mainnet wallets whose keys are held on the device participate in reminder evaluation and balance milestones.

Included:

- default Bitcoin and Liquid hot-wallet balances;
- imported hot wallets that sign locally; and
- the Ark balance, which is mainnet-only in the app.

Excluded:

- every testnet wallet and testnet backup record;
- watch-only wallets;
- watch-signer wallets; and
- hardware wallets.

## Backup completion timestamps

Backup timestamps represent successful completion, not the start of a flow.

Physical backup verification records one completion time after the mnemonic has been entered in the correct order and the updated backup state has been persisted. Wallets in the active environment that share the verified master fingerprint receive the same completion time.

Recoverbull records completion only after both the encrypted vault file and its server-held recovery key have been stored successfully. The completion update targets the exact wallet used to create the vault, preventing a testnet backup from changing mainnet backup state.

## Evaluation and persistence

The overlay evaluates when wallet data or the Ark balance changes, after its first frame, and when the app resumes. An empty or ineligible wallet list hides any previously visible reminder.

Reminder state is stored locally in a versioned SharedPreferences record keyed by master fingerprint. It contains only:

- the last acknowledgement time;
- the highest handled balance tier;
- a pending action start time; and
- the pending action balance tier.

No mnemonic, seed, private key, vault key, or other secret is stored or logged by the reminder. Malformed or unsupported reminder records are ignored and replaced with an empty in-memory record, which favors showing another reminder over suppressing one indefinitely.

## Architecture

The feature follows the repository flow described in `ARCHITECTURE.md`:

```text
overlay -> cubit -> use cases -> reminder repository -> SharedPreferences
```

The repository boundary uses a domain entity and a separate persistence model. Recoverable errors cross the UI boundary as typed failures and are translated in the presentation layer. Cross-feature calls use the public test-wallet-backup facade and route contract.

## Tests

The focused suite covers the posture matrix, exact 90-day boundary, strict balance thresholds, testnet and non-local-signer exclusions, pending actions, persistence corruption, physical completion, and Recoverbull completion ordering.

Run it with:

```sh
fvm flutter test test/features/backup_settings \
  test/features/onboarding/domain/complete_physical_backup_verification_usecase_test.dart \
  test/features/test_wallet_backup/domain/complete_physical_backup_verification_usecase_test.dart \
  test/features/recoverbull/domain/complete_encrypted_vault_backup_usecase_test.dart \
  test/features/recoverbull/recoverbull_bloc_test.dart
```
