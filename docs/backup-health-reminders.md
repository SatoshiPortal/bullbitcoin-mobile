# Backup health reminders

Every backup surface answers one question: **if this phone vanished right now, could you get your money back?** Each state has exactly one honest answer and exactly one thing to do about it.

| Situation | Honest answer | The one action |
| --- | --- | --- |
| Nothing backed up | No — the money is gone | Back up, urgently |
| Encrypted Vault only | Probably — it needs the server up and your PIN | Add a physical backup |
| Physical backup done (with or without a vault) | Yes — if the words are still findable and correct | Occasionally confirm that is still true |

## One surface per state

Three surfaces, three tenses, no overlap:

- the **every-launch warning** (`backup_warning_overlay.dart`) means "you are unprotected right now". Zero-backup only, unchanged by this feature.
- the **reminder popup** means "it has been a while, or something changed". Every posture except zero-backup.
- the **Backup Settings hero** means "here is your standing situation". Always available on the screen you visit deliberately.

So zero backup gets the warning and the hero, never the popup; every other state gets the popup and the hero, never the warning. One popup asks one question and offers one action.

## Reminder matrix

The reminder is evaluated for the default mainnet hot-wallet seed once at least one backup method has been verified.

| Verified backup posture | Reminder | Action |
| --- | --- | --- |
| No verified backup | None. The existing no-backup warning owns this state. | — |
| Encrypted Vault only | Every 90 days: without a physical backup you cannot recover if the vault server is unavailable. | Add a physical backup |
| Physical backup, with or without a vault | Every 365 days since the physical backup was last tested. | Test the backup |

There is deliberately **no vault-freshness or PIN reminder**. A vault-only wallet's real exposure is depending on someone else for its only recovery path, and the fix for that is a physical backup, not a PIN rehearsal. Once a physical backup exists, PIN rot cannot cost the user their money.

## Timing

A scheduled reminder is anchored on the clock of the thing being urged:

- vault only — the latest vault backup, or the last acknowledgement;
- physical backup present — the latest *physical* backup test, or the last acknowledgement. A fresh vault does not buy silence about words that were last read two years ago.

A verified backup with no completion timestamp is due immediately.

Dismissing a reminder snoozes it for a full cycle (90 or 365 days). It never writes a tested timestamp, so the Backup Settings screen keeps saying how long ago the backup was really tested while the popup is quiet. Only completing a verification flow resets that date; creating a backup counts as tested on day zero, because the creation flow tests it.

The popup is shown on the wallet home screen only, and only once the higher-priority no-backup and legacy-storage warnings are clear. A deep link or payment intent lands on its own route, so nothing ever stands between a payment and its completion.

## Balance milestone

The first time an evaluation observes an eligible balance of **10,000,000 sats or more**, the reminder is shown once, whatever the schedule says, with the posture-appropriate ask. The comparison is inclusive: exactly 10,000,000 sats counts.

That notice is retired for the lifetime of the wallet as soon as the user either dismisses it or acts on it. A balance later dropping below the threshold and crossing it again changes nothing — a wallet is told once.

## Eligible wallets and balances

Only mainnet wallets whose keys are held on the device participate in reminder evaluation and in the balance total.

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

- the last acknowledgement time; and
- whether the balance milestone has been shown.

No mnemonic, seed, private key, vault key, or other secret is stored or logged by the reminder. Keys written by an earlier shape of the record are ignored rather than rejected. Malformed, unsupported, or unreadable records are replaced with an empty in-memory record, which favors showing another reminder over suppressing one indefinitely. The underlying read failure is logged without exposing it to the user.

If a reminder action cannot be persisted, the overlay stays visible so the user can retry. A localized "close for now" action is then available as a session-only escape; it does not acknowledge the reminder, so the app evaluates it again on the next launch.

## Backup Settings screen

The screen is composed top to bottom as status rows, then at most one hero, then the settings menu:

1. **Status rows** — Physical Backup and Encrypted Vault, each Tested or Not tested, with a muted "Last tested …" line under a tested physical backup.
2. **Hero** — the single most useful action right now, or nothing at all: an urgent *Back up your wallet* card when nothing is backed up, *add a physical backup* for a vault-only wallet, *test your backup* once the physical test is over a year old, and no card when the physical backup is fresh. The hero derives its posture from the same domain code the reminder uses, so the two can never disagree.
3. **Menu** — Encrypted vault settings, Labels, Transaction History, plus the vault-key and test-backup entries when they apply. There is no "Start Backup" row: the zero-backup hero is the way in.

## Architecture

The feature follows the repository flow described in `ARCHITECTURE.md`:

```text
overlay -> cubit -> use cases -> reminder repository -> SharedPreferences
```

The repository boundary uses a domain entity and a separate persistence model. Recoverable errors cross the UI boundary as typed failures and are translated in the presentation layer. Cross-feature calls use the public test-wallet-backup facade and route contract.

## Tests

The focused suite covers the posture matrix, both cadences and their exact boundaries, the anchor rule (a fresh vault must not silence a stale physical backup), the inclusive milestone threshold and its once-per-wallet guarantee, dismissal snoozing without recording a test, testnet and non-local-signer exclusions, persistence corruption, and each hero the screen can render.

Run it with:

```sh
fvm flutter test test/features/backup_settings \
  test/features/onboarding/domain/complete_physical_backup_verification_usecase_test.dart \
  test/features/test_wallet_backup/domain/complete_physical_backup_verification_usecase_test.dart \
  test/features/recoverbull/domain/complete_encrypted_vault_backup_usecase_test.dart \
  test/features/recoverbull/recoverbull_bloc_test.dart
```
