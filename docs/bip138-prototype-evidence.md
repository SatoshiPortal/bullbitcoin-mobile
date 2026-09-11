# Prototype verification and review

This record covers `prototype/bullvault-bip138-nostr`, built from `80cf9ac6`, using FVM Flutter 3.44.9 / Dart 3.12.2. All published data and checked-in evidence use public, deterministic test keys. This is an engineering review of an isolated prototype, not an independent external security certification.

## Execution record

| Check | Evidence / outcome |
| --- | --- |
| Pinned upstream BIP138 encrypted-backup vectors | All seven evaluated, including rejection of the invalid zero nonce. Codec suite: 10 passed. |
| Real BullVault policy, NUMS exclusion and all three signing recipients | Repository suite: 2 passed. |
| Existing identity, scoped authors, signatures, identity changes, invalid inputs and use-case failures | 9 passed. |
| Relay boundaries, EOSE/auth/timeout, cancellation, single-key inputs, malformed input, forged duplicate poisoning and event tampering | 9 passed. |
| Independent RFC8439 decoder | `python3 tools/verify_bip138_fixture.py docs/bip138-evidence damus.json`: all three recipient keys decrypted the actual Dart-generated policy using Python cryptography. |
| Damus real Nostr round trip | Published and fetched three distinct events via `wss://relay.damus.io`; [public test evidence](bip138-evidence/damus.json). Transient handshake refusal reproduced and bounded reconnect/backoff verified. |
| Second relay | Published/fetched/verified all three new events via `wss://nos.lol`; [public test evidence](bip138-evidence/noslol.json). |
| Android recovery-only UI | Passed twice on Android 14, emulator-5582, including post-review repeat: three distinct nos.lol events, rendered policy and receive/change addresses at 0, 7 and 111. See [emulator record](bip138-evidence/emulator.json). |
| Standalone runnable APK | Built/installed/launched; native UI interaction fetched the inheritance backup and confirmed copy feedback, outside the test runner. [Record and APK hash](bip138-evidence/standalone.json). |
| Whole-project checks | `make checks` passed: whole-project analyzer, no Dart fixes, format check, 3,306 passing app/package tests and one opt-in live test skipped. [Counts](bip138-evidence/checks.json). |

The first emulator test passed weak assertions but its log showed the same event reused for three roles. That run is **not counted** as proof of three independent recoveries. The strengthened test waits for widget rebuilds, checks the actual input value, requires a new busy request and a distinct event for each role, then compares receive/change addresses at indices 0, 7 and 111.

## Review and fixes

Seven review lenses were applied and cross-reviewed: architecture, evidence, Dart/Flutter, UX, simplification, scope/deletion and AGENTS compliance. Security was also checked locally against the pinned BIP138 proposal, the actual crypto dependency implementation, untrusted relay inputs and independent decoder output.

| Finding | Applied correction / verification |
| --- | --- |
| PointyCastle 3.9.1 inherited `process()` omits AEAD finalization | Explicit `processBytes` + `doFinal`; upstream vectors, tamper tests and independent Python decryption. |
| BullVault public NUMS key was treated as an invalid signer | Reuse BDK facade's eligible signing-key extraction; actual three-role BullVault policy test. |
| An xpub-derived Nostr private signing key would let xpub holders impersonate the author | Keep private publishing material inside existing identity feature; derive separate scoped authors. Reader still treats policy provenance as unverified. |
| Single-key descriptor input inherited a full-wallet multipath restriction | Native single-key grammar validation separate from recovered full-policy validation; bare xpub, `/0/*`, `/1/*`, wildcard and origin/multipath key-expression regressions. |
| Invalid duplicate event IDs could hide a legitimate later copy | Only deduplicate IDs after signature/authentication/policy validation; signed regression verifies the valid later copy survives. |
| Relay verification/decryption could block UI | Bound candidates and decode/validate in an isolate; cancellation suppresses late results. Native execution is not forcibly interruptible. |
| Cancellation could race connection readiness | Recheck after ready; deterministic test verifies no REQ is sent. |
| AUTH/limited responses could look complete | AUTH/`more`, timeouts and event limits remain incomplete; explicit status in UI. |
| Unsupported authenticated content could look like no backup | Count it with rejected/unsupported events and display that outcome. |
| Retry could produce extra backup records or loop indefinitely | At most three attempts with bounded delay, reusing the exact signed event; cancellation ends further work. |
| Failed/cancelled publication could hide already accepted copies | Persistent partial-publication notice; no claim of retracting public events. |
| Clipboard feedback applied to unrelated candidates | Associate feedback with the copied descriptor and clear it on input/relay changes. |
| Deterministic fixture could retrieve an old equivalent record | Record publication IDs separately; validate this run's raw signed/decryptable event in addition to deduplicated policy recovery. |
| Unnecessary generic transport helper | Simplified to `Future<void>`; kept existing feature boundaries without registries, persistence or production wiring. |

Residual risks are explicit in [the protocol notes](bip138-nostr-prototype.md#security-and-recovery-limits): xpub disclosure grants recovery, unverified policy provenance, timing/network correlation, relay retention and censorship, response limits, post-allocation WebSocket frame limits, native parser trust and draft-profile compatibility. This prototype cannot establish a twenty-year recovery guarantee.

## Prototype checklist

- [x] Locate the metadata-on-BullVault base and isolate a prototype branch.
- [x] Reuse the existing policy, identity, UI and historical Nostr lifecycle.
- [x] Encode/decode pinned BIP138 payloads and wrap independently for each xpub.
- [x] Publish/fetch real Nostr data using all three actual account xpubs.
- [x] Review, fix security/correctness findings and simplify the implementation.
- [x] Finish strengthened emulator recovery and post-review repeat.
- [x] Finish whole-project checks, commit and leave a runnable harness installed.

Production work remains separate: metadata-server storage for the additional backup, settings integration, automatic lifecycle, recovery/import UX with provenance checks, relay retention/replication strategy and durable independent-reader specifications. OP_RETURN remains deferred.
