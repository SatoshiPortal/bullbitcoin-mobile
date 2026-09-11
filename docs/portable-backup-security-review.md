# Portable backup review record

Scope: replacement of the standalone age experiment with the existing RecoverBull encryptor on `distributed-resiliant-backups`, 2026-09-09. This is an engineering review, not an independent security certification. [The prototype specification](portable-backup-prototype.md) describes the exact derivation, format and retained limits.

## Current verification

The focused adapter/portable-backup suite passed 35 tests. Whole-project analysis, dependency lock enforcement and translation generation passed. Independent Python `cryptography` plus `hashlib`/`hmac` authenticated and decrypted the actual Dart-produced metadata and vault files, matched their exact contents, and produced a fixture that the Dart recovery harness decrypted to the exact original bytes. The checked-in core test now includes a small externally generated AES-CBC/HMAC vector for ongoing cross-implementation coverage.

The complete host suite passed 3,366 tests (3,188 root-app and 178 workspace-package tests), with three existing opt-in skips. `make fix-check`, `make format-check` and the Bull UI boundary check passed. The final focused adapter run passed all 11 tests, including the independently generated vector and the authenticated M+1-byte plaintext rejection added after the full suite had compiled the test. These final cases received a source re-review. Workstation evidence is under `/home/francis/recoverbull-prototype-evidence/`; these files are not runtime dependencies.

The actual Android emulator integration passed on `emulator-5582`: publication to `wss://nos.lol`, fresh password-only retrieval of the exact acknowledged event, full descriptor equality, receive/change addresses at indices 0, 7 and 111, and opening of the separate metadata file with the same password. Event ID: `0ff7b4e23a502fab666323b00f782891f8c170f86195f154241fb5d598ad9f3e`. The public synthetic vault file was 672 bytes; metadata was 1,472 bytes. A relay may later delete the event. These are current RecoverBull results, not historical age results.

Workstation logs: `/tmp/recoverbull-targeted.log`, `/tmp/recoverbull-unit-tests.log`, `/tmp/recoverbull-final-adapter.log`, `/tmp/recoverbull-analyze.log`, `/tmp/recoverbull-checks.log` and `/tmp/recoverbull-emulator.log`. Independent bidirectional artifacts and verifier are in the evidence folder above; seven first-pass and cross-review reports are under `/home/francis/recoverbull-prototype-review/`.

## Review scope

All seven review lenses completed first pass and cross-review: architecture, evidence/cryptography, Dart correctness, UX, simplification, deletion/scope and repository compliance. No source finding remains after the timing-test correction below. The new oversized-authenticated-plaintext test was also re-reviewed. The change removes the custom age cipher and delegates encryption and authenticated decryption to the pinned RecoverBull library. Production metadata credentials and server protocol remain unchanged.

Existing regressions retain coverage for mutable publication buffers, bounded base64/gzip parsing, hostile Nostr tags, failed native screen protection, cancellation, stale UI feedback, verified-author/profile lookup and metadata-after-vault recovery. New adapter tests cover compatibility with the public RecoverBull APIs, AES block boundaries, maximum input, fresh IVs, wrong keys, corruption in each wire section, truncation and mutable caller inputs.

## Review correction

The emulator metadata test assumed decryption would still be busy after one pump, which depended on age's slow KDF. It now accepts either an in-progress operation or completed metadata success, while retaining final no-error and exact success checks. The UX reviewer verified that no earlier metadata success can satisfy this sequence. No production UI change was needed.

## Deliberate limits

The encryption format uses RecoverBull’s existing AES-CBC plus HMAC construction, with the same 32-byte key for both. It is not an independently audited new protocol. Credentials have 128-bit entropy and inherit parent-seed weaknesses. The public Nostr author permits offline guess testing; user-created passwords are not supported. Password sharing grants both backup decryption and publication authority.

There is no rollback protection, exhaustive relay pagination, retention guarantee or 20-year availability promise. The prototype opens artifacts but does not integrate production server migration, wallet import or the password-derived Bitcoin format. Old age prototype events use a different profile and remain outside this reader. OS compromise, guaranteed memory erasure and WebSocket allocation before application bounds remain outside its protections.
