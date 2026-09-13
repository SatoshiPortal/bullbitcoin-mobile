# BULLVAULT: descriptor backup, additional protection and recovery UI

Status: UI/product proposal, 2026-09-09. Adds the user's requested flows to [ben-upstream-integration-plan.md](ben-upstream-integration-plan.md) and gives UI acceptance criteria to [distributed-backups-roadmap.md](distributed-backups-roadmap.md). This is a design plan, not implemented screens or permission to publish/pay. No app or backend code changed.

## 1. Product direction

Two simple journeys, not a new settings hierarchy:

```text
CREATE / RENEW
Review policy → Save/check this descriptor → Additional backup protection
              → Selected backup procedures → Backup results
              → Remaining signer/key-backup setup → Ready

RECOVER BULLVAULT
Plain descriptor ─────────────┐
BIP138 file + cosigner key ───┤
Cosigner key → server search ─┼→ Review recovered vault → Import → Find funds
12 backup words → file/search┘                                      → Set up signing
```

The first journey requires a real descriptor action before the additional-protection screen. A checkbox, merely showing a QR, or opening a share sheet is not sufficient. Following the user's scenario specification, manual recovery has three top-level choices: descriptor, cosigner public keys, magic backup key. The diagram shows their acquisition variants, not four menu items. Local BIP138 file recovery is retained under Import descriptor → Open file and as a file alternative in public-key recovery. All acquisition variants share policy review, normal wallet import and signer attachment. Automatic recovery after seed import is specified in R0 below.

Preserve the current BullVault entry points and design system. No new “family vault” concept, recovery dashboard framework, wallet hierarchy or gratuitous technical-details screen. This scope does not change what “Use key as signer” does.

### User requirements recorded as decisions

- A manual descriptor step is mandatory in setup; checkbox-only confirmation is removed.
- Offer scan, copy/paste and descriptor-file import mechanisms. The copy-versus-read-back distinction below must be resolved before implementing the gate.
- Immediately after the manual step, show **Additional backup protection** with three independent destination checkboxes: Bull Bitcoin server, Nostr, Bitcoin network.
- The server option is prominently recommended; Nostr is free but unreliable; Bitcoin requires explicit network-fee approval and offers long-term on-chain storage.
- Recovery starts with **Import descriptor**, **Import cosigner public keys**, or **Import magic backup key**. The last option is labeled with its input: **12 backup words—not signing-wallet words**.
- After seed import, automatically derive the established backup credential and check Bull Backup; notify on home only after successful vault import. Manual magic-word discovery searches Bull Backup → Nostr → Bitcoin in that order.
- The Bull server must support both eligible-cosigner lookup of BIP138 copies and magic-word-derived lookup of password-encrypted descriptor copies. These are required target capabilities, not existing-backend claims.
- A supported BIP138 encrypted descriptor file plus an eligible cosigner public account key must support local decryption without backup words, a server, a Mobile seed or signing-key import. This is a user-required flow; network access is needed later for transaction history and broadcast, not for opening the supplied file.
- The backup words are the encryption/discovery credential, not a spending wallet seed, hardware passphrase or six-digit RecoverBull PIN.

### Clarifications asked, not silently decided

**D1 — What completes the manual step?** The user's text includes copying the descriptor. A successful clipboard write can meet an action-based gate, but cannot prove a saved external copy exists. Recommended stronger option: scan, paste or import the saved descriptor back into BULL and verify it matches. If copy alone is accepted, preserve that route and call its result “Descriptor copied,” not “Backup verified.” No independent scan can be inferred merely because another device was pointed at the on-screen QR. The wireframes must show both variants until D1 is answered.

**D2 — Resolved at the product level by the user's scenarios:** an eligible cosigner public account key is sufficient input for lookup and decryption of its server BIP138 copy; no additional user-held access secret is specified. The backend must implement this explicit access model. Anyone with that same account key can retrieve/decrypt the copy: this is not independent secret authentication. Protocol details, abuse controls and privacy review remain implementation gates. This supersedes the older roadmap's open private-access choice for this UI target; do not silently retain an extra-credential requirement or remove private-versus-public storage separation. A local file still needs no server at all.

Other defaults in this document are recommendations for approval, not hidden protocol choices. In particular: optional backup failure does not block access to already-funded vaults; selecting a destination is not consent to unlimited future spending. The user's words-first server lookup now requires the separately addressable password-encrypted descriptor representation previously proposed in the roadmap. Neither requirement authorizes a deployment or publication during planning.

## 2. Current code and the changes this design requires

Inspected `distributed-resiliant-backups @ 7cf8694e6` and Ben's pinned `da6950a69` source. These are different trees; do not assume these flows already exist on either.

| Current implementation | Consequence for this UI |
| --- | --- |
| `ui/widgets/bullvault_completion_steps.dart`, `BullVaultRecoveryPackageStep`: Save action followed by a checkbox | Replace the checkbox with actual action/read-back results. |
| Our `ui/bullvault_recovery_package_share.dart` returns true after the share sheet opens | Never interpret that result as a verified backup. Ben's newer helper checks share success, but even that is not a matching read-back. |
| `BullVaultOnboardingCubit.confirmRecoveryPackage()` passes a Boolean to `UpdateBullVaultSetupUsecase` | Move verification to an owning use case; presentation cannot certify arbitrary input by setting a flag. |
| `ActivateInitialBullVaultUsecase` checks `recoveryPackageConfirmed` | Bind the new evidence to this descriptor/generation and enforce it at activation as well as in the button state. Inspect renewal and resume equivalents too. |
| Existing onboarding orders recovery package → hardware setup → mobile backup → complete | Insert additional protection directly after the descriptor step; do not accidentally remove hardware registration or Mobile Key backup. |
| `BullVaultRestoreScreen` combines label, Mobile Key passphrase, JSON import and descriptor paste/scan | Replace its initial form with the user's three task-focused choices. Ask for a signing passphrase later, only when attaching/using the matching key. |
| Existing `/bullvault/restore` and `/bullvault/scan` routes; scanner purposes include descriptor and public account key | Reuse these entry points. Add internal steps without a public deep link for every transient state; pass no secrets in route parameters. |
| Ben's newer restore returns `mobileAccess` but still obtains a default app seed | Reuse his importer, remove the seed prerequisite for watch-only recovery through roadmap P7, and do not equate Mobile Key status with the entire policy's spending capability. |
| Portable password recovery is a development harness, not production routing | These designs require real app import, not a successful harness decrypt followed by a success screen. |

The current [metadata server README](https://github.com/SatoshiPortal/BULL-metadata-backup/blob/master/README.md), checked via GitHub on 2026-09-09, documents one authenticated opaque head per BIP340 public key. Separate per-vault descriptor records, xpub-only lookup and words-only descriptor retrieval are backend work, not capabilities that an online existing server automatically provides. Its proxy source-address handling also means “no account required” must not be marketed as a proved anonymity guarantee.

## 3. Creating or renewing a vault

### S1 — Save your vault descriptor

**Headline:** Save your vault descriptor

**Body:** “Your keys are not enough to recover this vault. Keep its descriptor somewhere outside this phone.”

Display the vault label, network and policy identity; offer a large QR and the complete copyable descriptor. The QR and text must encode the complete descriptor, not a short ID, URL or screenshot of a truncated string. Offer the existing recovery JSON export containing the full descriptor. A PDF/printed kit can carry the same QR/full text; importing arbitrary PDFs is not assumed to be supported.

Actions:

| Action | Interaction | What the app can establish |
| --- | --- | --- |
| Scan saved descriptor | Open the existing descriptor scanner; scan the copy from paper/another screen | The decoded complete descriptor matches this prepared vault. Merely displaying the outgoing QR does not complete this route. |
| Copy descriptor | Explicit clipboard write of the full descriptor; tell the user to save it outside this phone | Clipboard write succeeded. Under the stronger D1 option, continue with “Paste saved descriptor” and compare it. |
| Import saved descriptor file | Open file picker; read supported descriptor text or recovery JSON and validate locally | The selected file contains this vault's descriptor. Canceling or selecting an unrelated file does not complete the step. |

Keep export/show actions distinct from proof: **Show QR** and **Save recovery file** help the user create a copy; **Scan saved QR**, **Paste saved descriptor** and **Import saved file** check it. Do not require a second device for everybody: file import and copy/paste are alternatives.

**Continue** is disabled until one allowed route succeeds for the current descriptor. Replace it with an enabled button and a small result line: “Descriptor matches this vault,” or, if D1 permits copy alone, “Descriptor copied—save it somewhere outside this phone.” Do not add a confirmation checkbox on top.

Recommended stronger flow:

```text
Save your vault descriptor

[ Show large QR ]   [ Copy descriptor ]   [ Save file ]

Check your saved copy
[ Scan QR ]        [ Paste descriptor ]  [ Import file ]

✓ Descriptor matches this vault
                                         [ Continue ]
```

The round-trip verifies content, not permanent storage or physical custody. Copy/paste back from the same clipboard also cannot prove an off-device copy. Instructions should state the actual requirement without claiming the app can prove more than it can.

**Validation:** compare the complete canonical public descriptor and network using the existing descriptor owner; include all receive/change branches and actual timelocks. Do not compare only a display fingerprint, a few characters, a file name, a balance or the number of signers. Reject private keys/descriptors. Accept harmless supported notation differences through the canonical parser, not arbitrary string rewriting.

**Failure paths:** camera denied → paste/file alternative; camera canceled → stay uncompleted; incomplete QR → keep scanning or offer file; clipboard failure → retry/other method; wrong vault/generation/network → explicit mismatch with no state write; malformed/oversized/unsupported file → safe error; storage failure after a match → completion remains pending with Retry. Do not send the descriptor to a server to verify it.

**Lifecycle:** persist only the minimal local evidence bound to the immutable descriptor identity/generation and allowed action method. Reuse existing identity fields where sufficient. Returning/back/restarting with the same descriptor retains successful evidence; changing keys, schedule or network invalidates it. A prior generation's checkbox/export receipt or a remotely restored flag is not proof of the new local step. Rename-only changes need not invalidate a descriptor match.

This gate controls completion of new setup/renewal in BULL; it cannot prevent somebody from deriving/funding an address in another application. It must not prevent viewing, recovery or emergency spending of an already-funded vault.

### S2 — Additional backup protection

**Headline:** Additional backup protection

**Body:** “Keep encrypted copies of your descriptor in more than one place. These backups do not replace your signing keys.”

Three selectable cards with actual checkboxes, not three new submenus:

```text
□ Bull Bitcoin server                    HIGHLY RECOMMENDED
  Encrypted backup. No account required.

□ Nostr
  Free encrypted backup. Availability is not guaranteed.

□ Bitcoin network
  Long-term encrypted backup on Bitcoin. Network fees apply.

                              [ Set up selected backups ]
```

Recommended default: all unchecked with a prominent recommendation badge on the server. This preserves explicit selection without adding a separate consent screen. A different preselection is a product choice; no request is sent merely because a card is selected or the screen appears.

If none are selected, the primary action becomes **Continue without additional backups**. It is enabled only after S1. A brief inline reminder says to keep the descriptor copy; no second nag dialog is necessary.

Suggested copy avoids overpromising:

- Prefer **No account required** to an unconditional “anonymous.” Explain any network/identity visibility in details, honor existing Tor/proxy settings, and make no unverified no-logging claim.
- Prefer **Long-term on-chain backup** to “eternal encrypted backup.” Explain that published ciphertext cannot be recalled, retrieval needs historical Bitcoin data, and recovery still needs the backup words. Do not promise everlasting encryption or guaranteed access from any server.
- Nostr's success indication is a current publication/read-back result, not a promise that relays will retain it. [NIP-01](https://github.com/nostr-protocol/nips/blob/master/01.md) distinguishes acceptance messages from event retrieval and permits retention behavior that is not an archive guarantee.

Expanded details can show what credential recovers each copy. Keep the terms BIP138, account xpub and OP_RETURN in help/details, not required first-screen vocabulary.

### S3 — Record your 12 backup words, when needed

Show this once when Nostr or Bitcoin is selected, and for any server representation/access flow that uses the same credential. Do not create a new password for each destination or renewal.

**Headline:** Write down your 12 backup words

**Body:** “These words recover your encrypted backups. They are different from the words that recover your Mobile, Cold or Inheritance Key.”

Use the protected reveal/record/re-entry flow from roadmap P3. All words should be re-entered or checked by the approved recording-confirmation mechanism before first public publication. Keep raw words inside protected input/operation scope, not route extras or Cubit snapshots. Reuse an already established credential identity; re-enter its words if the secret has expired rather than silently deriving a different one.

Explain once that these same words can unlock metadata backed up under the same credential. Giving them to an heir is not a vault-only sharing permission. They do not by themselves sign a vault spend.

If the correct originating seed is unavailable, allow entry of existing backup words. Do not generate replacements from an unrelated new app seed automatically. Establishing a new credential/namespace for a recovered vault is a separate explicit action; keep it out of the first recovery success path.

**Failure/cancel:** protection denied → no secret frame; invalid words/checksum → local correction; valid but different words → do not overwrite an established credential identity; cancel/background → no new publication, clear ephemeral material and return to selections. Already transmitted work is reconciled, not claimed canceled.

### S4 — Free destination procedures: one progress screen

Server and Nostr use one common results layout, with independent rows. They may run concurrently once their prerequisites are satisfied; one failure must not cancel the other or clear its successful receipt.

**Bull Bitcoin server:** establish the agreed access/record contract → encrypt the current descriptor representation(s) → store the exact generation → fetch/decrypt/compare → report success for those exact bytes. If only one of the server's promised recovery representations succeeds, show partial protection and the working credential, not a generic green “Server backed up.”

**Nostr:** encrypt the full public descriptor artifact using the backup words → persist the exact signed event before transmission → publish to the selected/configured relays → verify retrieval/decryption. Show “Available from 2 of 3 relays” rather than hiding partial success. Acknowledged but not read back is a distinct pending-verification state. Retry only failed destinations/relays and reuse the existing event.

Rows show a short status and contextual action: **Retry**, **Verify now**, or **Do later**. No fake progress percentages. Rate-limit responses show an honest retry time if known; unknown timing is not invented. Connection failures respect the user's proxy settings, with no silent clearnet fallback.

### S5 — Bitcoin backup: review and pay

Use an explicit fee-review screen, not payment triggered by checking the Bitcoin box.

Show:

- Vault and exact generation being backed up.
- Funding wallet, selected network and estimated network fee in sats and the existing fiat display where available.
- Total debit, including any required discovery-output amount, with normal funding change distinguished from cost.
- “This publishes an encrypted descriptor on Bitcoin. The published data cannot be recalled. Keep your 12 backup words.”

Primary action: **Pay [fee] sats and back up**, with total debit visible. Refresh/reconfirm if the fee, inputs or transaction meaning changes. Use the existing transaction validation, signing and pending-submission owner; do not add a backup-specific signing engine.

**Avoid the new-vault funding deadlock:** pay from an existing funded Bitcoin wallet. Do not instruct the user to fund the uncompleted vault to pay for its own mandatory setup. If no suitable wallet has funds, offer **Choose another wallet**, **Add funds to that wallet**, or **Do this later**. The third option preserves Bitcoin as pending/not completed and lets optional protection be deferred after S1. No fee sponsorship feature is implied.

A hardware-funded payment may enter the existing device-signing/PSBT flow. Canceling signing returns to payment review without payment. Persist the signed transaction and transaction ID before broadcasting. If the response is lost, show **Checking publication** and reconcile that transaction; do not create a second charge on Retry.

Statuses: **Needs payment**, **Signing**, **Publishing**, **Checking publication**, **Awaiting confirmation**, **Confirmed**, **Needs attention**. An accepted broadcast is not a confirmed on-chain backup. Confirmation/reorg handling uses the agreed chain policy, not an invented UI timer. Fee bump/replacement is offered only through supported transaction flows and explicit new fee approval.

### S6 — Backup results, then existing setup completion

**Headline:** Your descriptor backups

Show the local action and each chosen destination with method/generation and current status. For example:

```text
Saved descriptor     Matches this vault
Bull Bitcoin         Stored and checked
Nostr                Available from 2 of 3 relays
Bitcoin              Awaiting confirmation

[ Retry incomplete backups ]       [ Continue setup ]
```

“Continue setup” proceeds to Ben's remaining hardware-registration and Mobile Key backup steps. Those existing requirements/explicit deferral rules are not removed. Do not say the vault is ready before activation succeeds.

Recommended policy: selected additional destinations may be explicitly deferred after failure or while Bitcoin confirms; S1 remains mandatory. Show outstanding work in settings and after completion. Optional server availability must not become a custody condition or prevent access to existing funds. If the product instead requires all selected destinations to succeed before initial activation, that must be explicitly chosen; it also needs the fee-funding and offline escape cases above.

### Every destination selection combination

| Server | Nostr | Bitcoin | Procedure after S1 |
| --- | --- | --- | --- |
| No | No | No | Explicit continue without additional protection. |
| Yes | No | No | Server prerequisite/credential if required → store/verify. |
| No | Yes | No | Backup words → Nostr publish/verify. |
| No | No | Yes | Backup words → fee review/sign → Bitcoin status. |
| Yes | Yes | No | One credential setup as applicable → independent server/Nostr results. |
| Yes | No | Yes | Credential setup → server result and explicit Bitcoin fee flow. |
| No | Yes | Yes | One credential setup → Nostr result and explicit Bitcoin fee flow. |
| Yes | Yes | Yes | One credential setup → independent free-destination results → explicit Bitcoin fee flow. |

Free destination successes remain saved if the user cancels the Bitcoin step. Selecting Bitcoin never starts a payment without S5 approval.

## 4. Ongoing backup status and renewal

Provide **Backup protection** inside the selected vault's settings, reachable again without rerunning all onboarding. Keep the user's vault picker where needed; no new vault categories.

Display:

- Descriptor copy: **Copied** or **Checked**, with generation and date; do not imply present possession years later.
- Bull Bitcoin: exact representation/recovery method and last successful verification, or pending/failed status.
- Nostr: per-relay availability detail and last verification.
- Bitcoin: transaction ID, confirmation state and affected generation; link through the existing explorer/privacy flow only when requested.

Selecting/deselecting future protection is different from deleting existing backups. Turning off an option does not remove published Bitcoin data or guarantee deletion from relays. Server deletion, if supported, is a separate confirmed action. Preserve useful old descriptors and receipts.

At renewal, repeat S1 for the new descriptor; earlier generation evidence never unlocks it. Remember destination preferences, but show that they apply to the new generation. Automatic future free uploads require consent that explicitly covered renewals; otherwise reconfirm. Every new Bitcoin transaction gets its own fee approval. Preserve predecessor descriptors for funds left behind and label old/new generation backups separately. Backup cancellation must not silently cancel, activate or reverse the vault-renewal transaction.

## 5. Recover BULLVAULT: automatic recovery and three manual entry points

### R0 — Scenario 1: automatic discovery after seed import

1. Restore the user's seed through its existing protected owner. Derive the established BIP85 backup-word credential from the correct originating root, including any root passphrase required by that credential profile. An unrelated Cold/Inheritance seed derives a different backup identity; it does not recover the original Mobile seed's password namespace.
2. Derive the encryption material and Nostr/authentication identity from those magic backup words using the fixed profile. Current prototype evidence is `portable_backup/data/backup_password_material.dart`: reserved BIP85 entropy → mnemonic; mnemonic entropy → encryption key; domain-separated derivation from that key → Nostr signing identity. Reuse the profile; do not add a second derivation for automatic recovery.
3. Check the configured Bull Backup service under the seed-recovery journey's disclosed automatic lookup. Do not silently contact public relays or Bitcoin backup discovery in this automatic step; those are the manual fallback below. A reachable service can still have no record or no vault in its record.
4. Decrypt and validate recovered vault records, import them through the shared BullVault owner and identify actual matching local signers. Reuse the existing metadata recovery owner if recovering a complete Data Backup; descriptor-only records do not cause hidden metadata apply. Do not overwrite conflicting local wallets, select a new receiving vault automatically, or treat the newest advertised generation as authoritative solely because it decrypts.
5. Once home is visible and durable import has succeeded, show **BULLVAULT RECOVERED** with **View vault**. For several vaults, group the result rather than stack pop-ups. Explain the actual access state in the body: viewing only, matching signer available, or another key required. The title means the vault was imported, not that funds have been swept or are spendable now. If scanning is pending, say so. A decrypt/discovery result alone is **Vault backup found**, not recovered.

Do not hold home indefinitely for network discovery. Late successful imports can notify on home; no record allows normal home use and manual recovery. An unavailable service means **Backup check incomplete**, with Retry/Recover BULLVAULT available, not **No vault exists**. Cancel/restart must not create duplicate wallets or recurring success pop-ups; use the durable import result and minimal notification state. A conflict goes to review without an automatic success message. Do not publish an empty/new backup as a side effect of searching or restoring.

### Scenario 2 — Manual entry from settings

**Headline:** Recover BULLVAULT

**Body:** “First recover the vault's descriptor. Then connect or restore the keys needed to spend.”

```text
[ Import descriptor ]
  Scan its QR, paste the text, or open a plain or encrypted recovery file.

[ Import cosigner public keys ]
  Search a compatible Bull Bitcoin backup server.

[ Import magic backup key ]
  Enter your 12 backup words—not your signing-wallet words.
```

Show a small **Which one do I have?** disclosure: descriptor = long text/QR/file; encrypted descriptor = a backup file that needs its matching opening credential; cosigner public key = the vault account's public key from its wallet; backup words = the separate 12 words recorded for encrypted backups. A six-digit PIN or hardware passphrase is not interchangeable with any of these.

Expose this entry before requiring creation/restoration of the original Mobile Key. Existing users can reach the same flow from settings. Keep ordinary signing-wallet seed recovery available as a separate action, not a silent interpretation of anything pasted into the backup-words field.

### R1A — Import a descriptor

Offer **Scan QR**, **Paste descriptor**, **Open file** on one input screen. Supported text/JSON import is explicit; do not promise PDF extraction without an implementation. A paper/PDF kit uses its QR or full text.

Validate locally and proceed directly to the common review. No metadata service, Nostr, app seed, account login or Mobile Key passphrase is required to parse a public descriptor. Network access is needed later to find balances, not to establish descriptor syntax.

If the file is an encrypted backup, recognize only supported format identifiers and explain the required input: **Use a cosigner key to open this file** or **Enter your 12 backup words**. Preserve the selected bounded file while switching to the appropriate input flow. Never guess from a `.json` filename alone.

Cases: invalid/checksum-damaged/incomplete input → correct/retry; wrong network → explicit recovery-network choice; private-key-bearing input → reject safely without logging it; supported descriptor but not a BULLVAULT policy → offer the existing compatible descriptor-wallet route if supported, not relabel it BullVault; unsupported policy → no mutation, clear export/help route. Do not strip unknown policy branches to make import succeed.

### R1D — Open a BIP138 encrypted descriptor file (inside Import descriptor)

**Headline:** Open an encrypted descriptor file

**Body:** “Choose your BIP138 backup and provide a public account key from one of this vault's cosigners. This opens the descriptor; it does not give permission to spend.”

1. **Choose backup file.** Read a bounded file and identify the supported BIP138 profile from its contents, not its extension. Preserve the original file; never overwrite it with decrypted contents.
2. **Provide a cosigner public key.** Reuse R1B's scan/paste/public-key-file/device input and validation. Require an eligible key from this backup, not an arbitrary Bitcoin public key, address or fingerprint. Reuse a compatible key already explicitly supplied for this recovery operation without asking for it again.
3. **Open locally.** Decrypt and validate the complete public descriptor on this device. No server contact, backup-password prompt, seed import or publication occurs. If the key cannot open the artifact, allow another key or another file without discarding the other valid input.
4. **Review and import.** Enter R2/R3 with all supported candidates if the file contains several. Validate network, complete policy and relevant account-key membership; no wallet is created merely because decryption succeeded. Reuse R4–R6 unchanged.

Accept either input order: file-first reaches this screen through R1A's **Open file**; key-first R1B offers **Open encrypted backup file** and converges here. No fourth top-level menu item. Do not implement two decrypt/import engines. A password-encrypted descriptor file is a different format: offer an explicit switch to R1C with the selected file retained, rather than attempting to decrypt it with the xpub. Unsupported formats fail safely.

File missing, picker canceled, wrong/ineligible key, corrupted ciphertext, unknown version, excessive size, private-key-bearing plaintext and wrong network have distinct safe outcomes. No network fallback or automatic server upload on local failure. Offline success means **Descriptor opened**, not **Funds recovered**; history and signing remain separate.

The public key is sufficient for opening this compatible file, but is not a spending secret. Anyone with both the file and the eligible public account key can read the same descriptor. Never label this proof of ownership or a verified spending signer.

### R1B — Find a backup with a cosigner public key

**Headline:** Import a cosigner public key

**Body:** “Use the public account key that was added to this vault. You do not need to enter its seed words here.”

Offer scan/paste/supported public-key file and, where already supported, **Get key from hardware wallet**. Show how to select the same account and passphrase wallet on the device. Request the exact account xpub/key expression; a Bitcoin address, four-byte fingerprint, unrelated root xpub or on-chain child key is not an equivalent recovery input. Prefix normalization must preserve key/network identity; do not guess hardened account derivations from a public root.

After local validation:

1. Offer **Open encrypted backup file** as an offline alternative, handing the supplied key to R1D. Reuse only explicitly available recovery artifacts; do not scan arbitrary user cloud storage.
2. Offer **Search Bull Bitcoin backup** with visible server/network and consent to contact it. This succeeds only if a matching supported backup exists, can be retrieved under D2 and decrypts with the supplied eligible key.
3. Merge/deduplicate valid candidates and enter common review. If multiple vaults/generations match the same cosigner, show the candidate picker; do not assume one key means one vault.

The [pinned BIP138 draft used by the codec](https://github.com/pythcoiner/bips/blob/5af62cba9958a519218bcad8a0aae9e2090bb5bd/bip-0138.md) encrypts non-seed data for eligible descriptor keys; it does not supply our application's server discovery/authorization contract. Some keys are excluded. The UI must explain unsupported key inputs rather than promise any public key can recover any backup.

**Required xpub-input retrieval:** the backend must explicitly support key-derived lookup of matching ciphertext without another user-held secret. Avoid sending raw xpubs unnecessarily; exact lookup construction belongs to the protocol review. Anyone who obtains the relevant public account key has the same lookup/decryption capability. Do not call that an independent secret authentication factor or rely on it to protect against weak cosigner seeds if ciphertext leaks.

**Compatibility:** a server implementing only the older independently authenticated metadata endpoint does not satisfy this flow. Show unsupported service/access failure and alternatives instead of inventing a successful lookup. No additional-secret prompt is part of the newly specified default flow.

**Important:** a cosigner xpub does not derive the separate public-backup password. Do not fall back to Nostr/Bitcoin password backups without asking for the 12 backup words. Existing historical BIP138 public artifacts, if supported for reading, belong in an explicit compatible/legacy recovery option, not a new automatic public BIP138 writer.

### R1C — Use 12 backup words

**Headline:** Enter your 12 backup words

**Body:** “Enter the words you saved for encrypted backups—not your Mobile, Cold or Inheritance wallet's seed.”

Protected input, explicit paste, word-count/checksum validation and no telemetry. Do not add a passphrase field here: the frozen credential profile has no extra passphrase. A valid BIP39 phrase does not prove it is the correct backup credential; no-result/decrypt failures must not be mislabeled as a definite wrong password.

Show the search order **Bull Backup → Nostr → Bitcoin** above **Find my vault**; do not make users pick sources to get the normal fallback. Keep **Open encrypted backup file** as a local alternative. The words-only Bull step requires the separate password-encrypted descriptor copy. Do not fetch all metadata invisibly to extract the vault or attempt to open BIP138 bytes with the password.

One explicit search action starts the disclosed fallback sequence. No contact merely from entering words. Check Bull Backup first; if there is no usable descriptor, it is unavailable, its response is invalid or its bounded lookup fails, record that outcome and continue to Nostr, then Bitcoin. Do not let one offline source block the next indefinitely. Preserve source-specific failure states and existing proxy policy; no silent clearnet fallback. Configured defaults make discovery usable without an event ID/txid; custom forgotten endpoints cannot be found magically from words.

On usable candidates, enter common review without forcing later-source requests. Finding a candidate is not proof all vaults/generations were found: offer **Keep searching other sources** if the desired vault or generation is missing. Cancellation stops further lookup and does not discard already recovered/imported descriptors. Bitcoin discovery uses the password-derived marker's transaction history to locate the encrypted OP_RETURN payload, including when the marker output has been spent; it is not a blind whole-chain scan or a new paid transaction.

After all attempted sources yield no usable descriptor, show **Descriptor backup could not be found** with the source results and **Try cosigner public keys**, **Import descriptor** and **Retry**. If any source could not be checked, add **Some backup sources were unavailable; the search is incomplete**. Do not assert there is no backup anywhere or that valid-checksum words are definitely incorrect.

Display per-source progress/outcome. Derive the public lookup identities locally; never upload the words, encryption key, mnemonic-derived private key or raw credential. Bitcoin recovery reads transaction history, including spent discovery outputs; searching does not pay a network fee or require the original funding wallet.

### Credential/source matrix

| Available input | Descriptor file | Local BIP138 file | Bull server BIP138 | Nostr public password copy | Bitcoin public password copy |
| --- | --- | --- | --- | --- | --- |
| Complete public descriptor | Direct local import | Not needed | Not needed | Not needed | Not needed |
| Eligible cosigner account key | Cannot reconstruct a missing descriptor by itself | Decrypt locally | Matching record + service + D2 access rule | Needs backup words | Needs backup words |
| Correct 12 backup words | Not needed if descriptor already supplied | Also needs cosigner key | Also needs cosigner key; password server representation is a separate route | Available relay retaining the correct artifact | Compatible history source retaining the transaction |
| Signing seed/PIN/device passphrase only | Use the separate signing-wallet recovery path; it does not replace a missing descriptor | Derive/export the correct eligible public account key through its owning wallet first | Same, plus service/access conditions | Original Mobile seed may regenerate its own backup words through the existing derivation flow; arbitrary cosigner seeds cannot | Same credential requirement |

The required Bull server password-encrypted descriptor representation lets backup words retrieve/decrypt that record independently of BIP138. Until implemented, this part of the intended flow is unavailable; password words do not decrypt the BIP138 file itself.

## 6. Common recovery screens

### R2 — Backups found

For one supported candidate, go directly to its review. For several, show a list of vaults/generations with network, known exact policy dates, short identity and sources. Unknown labels/dates are shown as unknown; do not invent names such as “Family Vault.” Do not call the highest generation or newest event the current vault without evidence.

Deduplicate the same canonical descriptor on the same network across sources while retaining source results. Older funded generations remain selectable. Show **Search incomplete** when a source fails or a resource/history limit is reached; finding one candidate does not prove all vaults have been found. Let the user review found candidates without waiting indefinitely for a failing source.

### R3 — Review recovered vault

Use the actual policy viewer: permitted signer combinations, unlock conditions, exact encoded dates, optional inheritance/mobile-alone paths, and the correct network. Map identities to known labels only when justified; otherwise show “Signer” plus a short public identity. A matching imported xpub is not proof the user currently possesses its private signing key.

Show the source(s), editable local label and whether any matching signing capability is already available on this device. Hide raw descriptor details behind an optional expansion; keep copy/export possible. No forced Mobile Key passphrase field.

Primary action: **Import vault**. Secondary: **Back**. No database mutation from simply previewing; no automatic balance search before consent if it would reveal descriptor-derived addresses to a new endpoint. Successful decryption/authentication means the artifact is readable and unmodified under that credential, not that the Bitcoin spending quorum approved its contents. Never automatically redirect the user's current receiving vault from an advertised candidate.

### R4 — Import vault

Use BullVault's existing importer adapted for seedless watch-only operation, normal app storage and idempotency. Existing same vault → **Open existing vault**, preserving local preferences. Conflicting ID/policy/lineage → show the conflict and do not overwrite. One import failure must not erase earlier successful imports.

Persist record/wallet visibility consistently under Ben's lifecycle rules. Recovered annotations must not hide/replace an active wallet without the intended, validated lifecycle transition. Once committing begins, cancellation is not a claim of rollback; reconcile the result before offering another import. A restart discovers a completed import rather than creating a duplicate.

### R5 — Find your funds

**Headline:** Vault imported

**Body:** “Now checking this vault's transaction history.”

Use the production wallet sync path for both receive and change branches. Show actual activity/progress only where measurable. **Scanning**, **Balance found**, **No funds found in the scanned range**, **Scan incomplete**, and **Offline—scan later** are different states. Never show a complete zero balance after a timeout or fixed prototype scan window.

Allow **Open vault** while scanning or offline; the persistent descriptor remains usable. Provide **Continue search** / existing scan-range controls when the supported discovery strategy requires user continuation. Do not infer wallet birthday solely from backup publication time. A direct descriptor import can succeed offline even though history cannot yet be fetched.

### R6 — Set up access to your funds

Recovery success is two separate facts: descriptor imported, and sufficient signing capabilities/time conditions available.

**Scenario 2.1 — A matching signing wallet is already present:** check all local signing wallets, not only the default wallet and never only a four-byte fingerprint. Match the full canonical account identity and policy key/origin. Show the decoded policy with that signer's current capabilities: can spend on an available route, needs another specific signer, locked until unlocked, or cannot spend alone until a later policy condition. Do not ask for words already represented by a usable local signer. Complete descriptor import even when the available key does not yet satisfy a spending path.

**Scenario 2.2 — No matching signing wallet is present:** preserve the current unrelated mobile wallet. Show the policy's currently available combinations and let the user choose a route they can satisfy. Ask only for the missing signer(s) in that route: one for a mature single-key recovery path; two for a selected two-key path. Offer mnemonic plus optional wallet passphrase, and hardware/external signing when supported so a hardware owner is not forced to export a seed. Verify each imported account against the policy before marking it local. A wrong passphrase can produce a valid but nonmatching wallet; do not mark it recovered.

Cold and Inheritance are the expected choices for an heir, but must not be hardcoded as the only choices. For the example policy, Cold + Inheritance cannot spend before their two-year condition; immediately after creation the usable combination is Mobile + Cold. After the three-year condition, Cold alone is enough; after the five-year condition, Inheritance alone is also enough. Show exact conditions from the actual descriptor and chain state. If no presently available route can be satisfied, offer a future route and **Continue viewing only** rather than demand keys that still cannot spend or claim that importing both bypasses the timelock.

**Scenarios 2.3 and 2.4:** server BIP138 discovery and magic-word fallback both converge on these same two branches after descriptor validation. They must not each implement their own key-matching, key-import or spending-policy logic.

| Situation | Show | Next action |
| --- | --- | --- |
| Descriptor only; no private signer attached | “Vault imported. Connect or restore a signing wallet to spend.” | Connect wallet / restore signer / view-only. |
| One key attached but current policy needs two | Which permitted second key is needed | Connect that wallet; do not imply the descriptor completes the quorum. |
| Sufficient keys for an available path | Permitted spending combination | Existing Send/PSBT flow. |
| Key works only after a later condition | Exact policy condition/date and current chain-check status | Keep vault viewable; show later recovery route. Do not use device clock alone as final spendability proof. |
| Mobile session locked | “Unlock your Mobile Key to sign.” | Existing protected unlock; no seed-store fallback. |
| Hardware wrong account/passphrase/device unsupported | Specific local ownership/support error | Choose correct wallet/account or an existing external-PSBT route. |
| Lost Mobile Key, Cold or Inheritance available | Paths involving available key(s), now or later | Recover/connect the relevant signer; original Mobile Key not mandatory. |

Use existing hardware and signer-import flows; never request hardware seed words merely to read its public key. If an heir chooses to import an Inheritance mnemonic/passphrase from a kit, make that a distinct protected signing-key import with explicit custody implications. Finish by checking the derived key matches the selected policy before marking it local. Canceling signer setup leaves the imported vault available for viewing.

Then offer **Review backup protection** without blocking access to recovered funds. Importing a descriptor from a server is not evidence that a new manual external copy has been saved. Do not silently publish a recovered descriptor under an unrelated new Mobile seed's backup identity.

### Worked inheritance recovery: two distinct sets of 12 words

The intended end-to-end flow is **12 backup words → retrieve/open a compatible descriptor backup → review/import vault → restore the Inheritance signer using its own 12 seed words and optional wallet passphrase → verify the derived account matches the descriptor → scan and spend when the policy permits**. Before the inheritance-only condition matures, another permitted signer may be required. The original Mobile or Cold key is not required for an available inheritance-only route.

Backup words and signing words must remain separate input actions; never silently import the backup password as a spending wallet. Words cannot recreate an unpublished or unavailable descriptor backup. If the user instead has a BIP138 file, an eligible public account key derived through the restored Inheritance wallet can open it through R1D without the backup words. Supplying an xpub directly still creates only viewing capability until a real signer is attached. These are acceptance requirements, not a claim that the current production UI has these flows wired end to end.

## 7. Failures and alternatives: keep dimensions separate

Model reusable outcomes rather than hundreds of duplicated screens. Every applicable combination is assembled from independent credential, source, candidate, import and signer states; test the security-sensitive interactions explicitly.

| Condition | User-facing result | Available next step |
| --- | --- | --- |
| Bull backup server unreachable | “Could not reach Bull Bitcoin backup.” | Retry, open local descriptor/BIP138 file, or use backup words with another available source. |
| RecoverBull seed-recovery service unavailable | Separate seed-recovery failure; descriptor backup status unchanged | Physical signing-seed backup or other signer route. Never call this a metadata/descriptor server outage. |
| Server accessible but lookup/authentication rejected or recovery capability unsupported | “This server could not provide the backup through this recovery method.” | Retry with the correct supported service/credential or open a local file; no invented additional user secret in the cosigner-key flow. |
| Server accessible, authorized, no matching record | “No matching backup found on this server.” | Correct account/network/source or use another artifact. No claim that funds do not exist. |
| Nostr partly unavailable | Per-relay result; “Search incomplete” where applicable | Review found vaults; retry failed relay or change configured source. |
| All relays unavailable | Nostr-specific failure | Bitcoin/server if compatible, or supplied file. |
| Electrum/history server unavailable or history unavailable | Bitcoin search incomplete, not “No Bitcoin backup” | Retry with another compatible server; local transaction/file where supported; other sources. |
| Marker output already spent | Still search historical transactions | Normal Bitcoin descriptor discovery. |
| Pending/replaced/reorged backup transaction | Publication not yet confirmed or needs reconciliation | Track exact existing transaction; approved fee action if supported. |
| Missing backup words | Public password backup cannot be opened | Manual descriptor or eligible cosigner plus accessible BIP138; regenerate only from the correct original Mobile seed through its owning flow. |
| Forgotten RecoverBull PIN | Seed-vault-specific problem | Physical Mobile seed or other signing keys; do not ask for this PIN to decrypt descriptor password files. |
| Forgotten hardware passphrase | Correct private account may be unavailable | Other policy signers/time paths. Public descriptor discovery may still work with a saved correct xpub or backup words. |
| Words pass checksum but no matching artifact | “No backup found in the sources checked.” | Check which words/account/network/sources; do not assert the words are definitely wrong. |
| Ciphertext found but cannot authenticate/decrypt | “This backup could not be opened with the supplied credential.” | Correct credential or another intact copy; no destructive import. |
| Correct account key excluded/not supported by artifact | Explain this key cannot open that copy | Another eligible cosigner key or descriptor/password route. |
| Corrupt/oversized/unknown-profile file | Safe localized format failure | Another copy or supported recovery tool; no parser crash/secret logging. |
| Metadata file supplied to descriptor-only flow | “This is a Data Backup file.” | Explicitly switch to Data Backup recovery or choose a descriptor file; no hidden metadata apply. |
| Multiple vaults/generations or conflicting candidates | Candidate/policy review, not automatic replacement | Import one at a time; preserve funded older generations. |
| Network disagreement | Explicit network mismatch | Select compatible recovery network; no silent switch of app automation/proxy settings. |
| App terminated during fetch | Search paused; credential may need re-entry | Resume selected sources without using a different identity. |
| App terminated during upload/broadcast | Outcome needs reconciliation | Verify the persisted event/transaction before any retry that could duplicate work/payment. |
| App terminated during import | Imported or not imported, determined from durable state | Open completed vault or retry the unresolved operation; no duplicate wallet. |
| Descriptor imported, scanning interrupted | “Vault imported; history check incomplete.” | Open vault and retry scan. |
| No descriptor in any accessible source | “The keys alone cannot reconstruct this vault.” | Find another descriptor/recovery kit/backup source. Waiting for a timelock does not repair a missing descriptor. |

### Stolen material is a different branch from lost material

- Stolen descriptor/xpub: disclosure of vault information or access to compatible encrypted copies, not automatically spending authority. Review which private keys/backups were also exposed.
- Stolen backup words: treat the affected backup namespace as compromised, including metadata encrypted with those words. The words alone do not sign vault transactions, but a holder may forge readable backup candidates; never trust a newer candidate automatically. Public ciphertext cannot be recalled.
- Stolen device/seed/Cold or Inheritance kit: treat the relevant signing key as potentially compromised. Show current policy routes and route to existing spend/renewal functionality where authorized; do not promise timelocks prevent every combination of compromised keys.
- Lost and stolen cases must not be combined into “just wait.” Descriptor discovery and spending authority remain separate checks in either case.

## 8. Architecture and minimum durable state

Follow the integration plan's ownership rules. UI is not a second backup engine.

| Owner | Domain / data | Presentation / UI / public boundary |
| --- | --- | --- |
| BullVault | Manual-descriptor evidence, generation lifecycle, selected destination intent/receipts, candidate validation and real import | Thin setup/recovery Cubits; own use cases; published contracts through BullVaultFacade. |
| PortableBackup | Existing password profile, artifact opening and public transport capabilities after roadmap hardening | Narrow public facade; protected credential UI/capabilities, no raw secret-returning public convenience API. |
| WalletBackup | Metadata snapshot/apply and its durable job runner | Data Backup UI stays separate. Descriptor-only recovery must not invoke metadata apply. |
| Shared wallet/transaction infrastructure | Existing parser, wallet sync, signer ownership, pending transaction validation/signing | Reuse Send/hardware/PSBT public flows; no new payment engine. |
| App composition | Entry before seed onboarding, recovery follow-up navigation and DI | Own route integration without feature cycles; `FEATURES.md` updated with actual edges. |

Minimal additions, proposed rather than claimed existing APIs:

- A purpose-specific descriptor-action/verification use case: receives an allowed observed result or imported descriptor, checks the current immutable identity, and persists minimal evidence. Remove arbitrary `recoveryPackageConfirmed: true` setters from the new completion path.
- Store current selection separately from actual per-destination results. Receipt identity binds network, generation and exact artifact. Reuse roadmap-owned publication persistence, not duplicate it in a Cubit or UI table.
- Small source-specific statuses map to shared progress cards. Do not create a generalized destination plugin system or a persisted row for every animation/search phase.
- Recovery candidates and credential handles live for the operation; private values are cleared on appropriate lifecycle events. Persist only nonsecret identity/resume information and completed wallet state.
- Manual evidence is local to the operation/installation; a remote metadata flag cannot mint it. Existing already-funded wallets remain accessible while a new generation's evidence is pending.

No raw seed/words/passphrase in GoRouter state, query parameters, clipboard auto-read, analytics or debug strings. Public keys/descriptors are privacy-sensitive even though they cannot spend; avoid unnecessary logging and remote disclosure. Do not secretly clear the descriptor clipboard immediately after the user explicitly chose Copy as a backup action.

## 9. Implementation chunks and dependencies

All work remains small, reviewable chunks. The integration restack stays separate from product-flow changes; the old “share sheet counts as export” patch is now intentionally superseded by this user request, not silently lost in a merge.

| Chunk | Scope and concrete areas | Tests and exit criteria | Dependencies |
| --- | --- | --- | --- |
| U0: lock UI contract and clickable design | This document; next HTML prototype using current BullVault layout/tokens. Resolve D1, implement D2's chosen public-key-input access contract in later backend chunks, record optional-destination deferral and credential copy. | Automatic scenario 1, all three manual entry points including encrypted files, scenarios 2.1–2.4, eight destination selections and common failure states navigable in the mock; no fictional backend success presented as app behavior. | No production services needed. |
| U1: enforce manual descriptor gate | `bullvault_completion_steps.dart`, onboarding/renewal state/Cubits, setup and activation use cases, record persistence, scanner/file/clipboard interactions | Checkbox/share/QR-display alone cannot pass; allowed action completes only current descriptor; mismatch, cancel, restart, stale generation and direct activation bypass tests. | Ben SQLite integration; D1. |
| U2: common descriptor review/import | Restore screen/Cubit/use case and facade, policy viewer, app recovery route | Direct file/paste/scan reaches preview without seed; no mutation before import; normal persistent wallet, repeated import/conflict, unsupported policy and scan-interruption tests. | Roadmap P7 importer/boot/sync changes. |
| U3: additional protection and credentials | New scoped step in existing setup flow, portable protected password lifecycle, destination intents/results | Eight selection combinations; selected is not saved; canceled credential entry sends nothing; no lost successful row after another fails. | Roadmap P2/P3 contracts; actual destination execution added in following chunks. |
| U4a: local BIP138 file recovery | Existing BullVault codec/repository, shared public account-key input, R1D under Import descriptor and key-first convergence | All eligible Mobile/Cold/Inheritance account keys independently decrypt a fixture; wrong/excluded key, malformed file and cancellation rejected safely; airplane-mode decrypt/review/import; public-key-only import cannot sign; no server request. | U2 plus supported BIP138 profile validation; independent of backend work. |
| U4b: Bull server and xpub discovery | Private descriptor repository/facade, backend records/lookup/access, server progress UI; reuse U4a opening and U2 import | Server absent vs offline vs access denied; no raw-key/words leaks; required password representation and BIP138 representation individually verified through their respective credentials. | D2 plus roadmap P0/P4/P6 and U4a. |
| U5: public Nostr and word discovery | Production portable facade, recovery source picker, candidate list, per-relay rows | Real password-derived publication/fetch/import on isolated emulator; failed relay, lost ACK, unknown profile, multiple generations and incomplete history. | Roadmap P8 and U2/U3. |
| U6: Bitcoin procedure and word discovery | Existing fee/sign/broadcast flows, durable intent, Electrum history, Bitcoin result card | Explicit fee consent; no funded-wallet deadlock; cancel/signing/lost broadcast result/reorg; spent marker and fresh-emulator restoration of the actual password-profile artifact. | Roadmap P9/P10 and U2/U3. |
| U7: lifecycle and settings polish | Selected vault backup protection screen, renewal, existing recovery/signing routes and copy | New-generation proof required; old receipts never satisfy new copy; failed optional service cannot block existing funds; partial recovery and destination status truthful. | Roadmap P11; U1–U6 as applicable. |
| U8: automatic recovery and home notification | Existing wizard seed-import/recovery owner, WalletBackup/BullVault public contracts, portable derivation owner and home presentation; do not place orchestration in widgets | Same seed gives same backup identity as manual words; unrelated seed gives no false match; delayed server does not block home; no popup on mere fetch/decrypt or failed import; actual durable import then one grouped popup; restart/dedup/conflict and no accidental upload tests. | U2, production password lifecycle/compatible Bull records from U3/U4b; existing full-metadata recovery stays owned by WalletBackup. |

Do not ship enabled checkboxes backed by no-op implementations. A clickable HTML mock may simulate all states, but production routes activate only with their actual protocol/storage/security gates. U1 and direct/local-file recovery should not wait for Bitcoin publication; the complete advertised three-destination journey cannot be called finished without it.

Use existing shared widgets/theme and `context.loc`; localization changes go through `tools/arb.dart`. No new dependencies assumed. Reuse file picker/scanner only for formats they actually support; large/multipart QR support is an explicit implementation check, with file/paste alternatives rather than silently accepting partial payloads.

## 10. Verification and review gates

Each chunk: targeted entity/use-case/Cubit/widget tests → required codegen/migrations/l10n → whole-project `make analyze` and applicable `make checks` gates → seven solo review lenses → fix findings → material re-review. Preserve the user's no-subagent instruction. The lenses cover architecture, evidence, Dart/async, UX, simplification, deletion/scope and AGENTS compliance, with security checks in every secret/persistence/payment change.

Use FVM and the current makefile; no dependency refresh to fix integration inconvenience. Run `make build-runner`, `make translations` and `make drift-migrations` only for changed inputs, and inspect generated output. Published schemas remain immutable; unreleased additions join the one agreed pending migration.

Add targeted tests for the cross-products that can lose data or mislead users, not just isolated happy paths:

- Copy/scan/file action × cancel/failure/mismatch/restart × new versus old generation.
- Every destination selection × missing credential × one/all sources offline × leaving setup.
- Server upload complete/Nostr failed/Bitcoin broadcast uncertain, followed by restart and Retry: only unresolved work resumes, without a second Bitcoin payment.
- Each recovery credential × each compatible source × missing/offline/unauthorized/invalid/partial result.
- Magic-word fallback observes Bull → Nostr → Bitcoin order; offline/corrupt/no-record/timeout continue to the next source; first usable candidate permits review without claiming search completeness; explicit continuation finds other generations; cancellation and wrong-network outcomes do not import or send further requests.
- Scenarios 2.1/2.2 with a matching default signer, a matching nondefault signer, only a public key and no matching signer; ask only for the chosen route's missing keys, preserve unrelated wallets, and never claim Cold + Inheritance can spend before the actual timelock.
- Scenario 1: original seed vs unrelated cosigner seed, root-passphrase distinction, no record vs offline, delayed home notification, multiple recovered vaults, import failure/conflict, restart and no success-before-commit; no public-relay search or backup publication silently added to seed recovery.
- Local BIP138 file-first and key-first converge to the same result with all network services disabled; each eligible cosigner independently opens it without backup words or a signing seed; no hidden upload, server lookup or private-signer flag.
- Fresh-app inheritance fixture: backup words recover an actually stored descriptor, separate inheritance seed/passphrase matches its account, inheritance-only spend rejected before its chain condition and accepted after it; wrong seed/passphrase or absent descriptor cannot produce a spend-ready success. Repeat descriptor acquisition through local BIP138 plus the eligible inheritance account key.
- Descriptor recovered × no signer/one signer/enough signers/locked signer × current/future policy path.
- Multiple sources advertising the same descriptor or conflicting generations; no automatic active-vault replacement or hidden metadata import.
- Secret-protection true/false/null/error/delay, nested pop and backgrounding; no secret frame or raw secret in logs/exceptions/semantics.
- Wrong network, oversized QR/file, private descriptors, valid but wrong backup words and a missing full descriptor despite intact keys.

Emulator proof uses an isolated disposable profile and synthetic credentials. Capture UI navigation and sanitized logs for setup, partial failures, force-stop/restart, seedless descriptor import, scan continuation and signer attachment. Hardware and iOS behavior require their own real-device evidence; mocks are not a substitute. Public test publication/testnet fees require explicit test authority; no real user material is used. Rebuild the normal app entry point after integration tests.

### Scope and deletion pass

Remove the checkbox-only path, stale confirmation setters/booleans where superseded, duplicate progress screens, orphaned translations/mocks and obsolete export-success assumptions. Keep necessary historical recovery readers, the entire descriptor text and original test evidence. Do not remove old funded generations or saved artifacts to simplify the UI.

The planning skill shaped the owner boundaries, testable states and chunk gates. This document was prepared and challenged by one planner; it does not claim implementation or independent multi-agent review. D1 remains open. The user's scenario specification resolves D2's input model and requires the password-encrypted server descriptor representation; backend protocol/security verification is still required before implementation can claim those routes work.
