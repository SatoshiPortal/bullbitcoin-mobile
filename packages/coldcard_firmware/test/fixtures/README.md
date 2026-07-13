# Test fixtures

| File | What it is |
|---|---|
| `signatures.txt` | Real Coinkite release manifest, snapshotted 2026-07-13 from https://raw.githubusercontent.com/Coldcard/firmware/master/releases/signatures.txt. Clear-signed by the production Coinkite key (fingerprint `4589779ADFC14F3327534EA8A3A31BAD5A2A5B10`) — tests verify it against the key bundled in `lib/src/firmware/trusted_key.dart`. |
| `page_q1.html` | Real https://coldcard.com/downloads/q1 page, snapshotted 2026-07-13 (latest: v1.4.1Q). |
| `page_mk.html` | Real https://coldcard.com/downloads/mk page, snapshotted 2026-07-13 (latest: v5.5.1). |
| `test_key_public.asc` | Throwaway RSA-2048 signing key generated for these tests only (`Coldcard Firmware TEST Signer (do not trust) <test@invalid>`, fingerprint `D63D334E08F1530DCBF87402915E31D6CCA4E552`). Its private half lives nowhere durable — it exists so tests can exercise wrong-key and end-to-end paths without Coinkite's private key. |
| `test_manifest_clearsigned.txt` | Manifest listing `fake_firmware.dfu` under two fake release names, clear-signed by the test key. |
| `fake_firmware.dfu` | 4096 deterministic bytes (`(i * 7 + 13) % 256`) standing in for a firmware download. NOT real firmware. |

Refreshing the real snapshots (optional, when Coinkite ships new releases):

```sh
curl -sL https://raw.githubusercontent.com/Coldcard/firmware/master/releases/signatures.txt -o signatures.txt
curl -sL -A "Mozilla/5.0" https://coldcard.com/downloads/q1 -o page_q1.html
curl -sL -A "Mozilla/5.0" https://coldcard.com/downloads/mk -o page_mk.html
```

Tests pin behaviour, not versions, except the few assertions on v5.5.1/v1.4.1Q
hashes in `manifest_test.dart`/`discovery_test.dart` — update those alongside a
snapshot refresh.
