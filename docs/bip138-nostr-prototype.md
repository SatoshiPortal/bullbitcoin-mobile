# BullVault descriptor recovery prototype

This branch adds a separate runnable Flutter harness that publishes a synthetic BullVault's encrypted descriptor to a public Nostr relay, and fetches/decrypts it using any one of its mobile, cold or inheritance account xpubs. A recovery-only entrypoint needs no wallet seed, metadata-server account, publisher identity or cached event. It displays the recovered policy for inspection and copying.

This is an additional descriptor backup experiment. The normal metadata backup is unchanged. Production settings integration, metadata-server storage of this second backup, automatic publication/republication, wallet import and OP_RETURN are outside this prototype. No private wallet keys are included in a descriptor backup. Do not fund the public test keys.

## Branch and reuse

- Branch: `prototype/bullvault-bip138-nostr`, based on committed `integration/bullvault-metadata-deterministic-keys` at `80cf9ac6`.
- Historical clue: `pr21-nostr-keychain-manifest-fetch-import` at `7d758a89`. The relay datasource reuses its ready / matched OK / REQ / EOSE / CLOSE lifecycle, with finite responses, explicit incomplete results and cancellation.
- Existing BullVault policy construction and BDK descriptor validation are reused.
- Existing `nostr_identity` facade and BIP85 identity reservation are reused for signing. Fetching does not resolve this identity.
- Existing Bull UI, localization and screen privacy components are reused.
- Ownership: BullVault owns the codec, relay data layer, repository contract, use cases, cubit and screen. `tools/bip138_prototype_app.dart` is the isolated composition root. The production router and app initialization are unchanged. `FEATURES.md` records BULLVAULT → NOSTR_IDENTITY. The already-existing BULLVAULT → RECOVERBULL → WALLET_BACKUP → BULLVAULT cycle is not introduced or repaired here; its previously omitted WALLET_BACKUP edge is now documented.

## Experimental wire profile

The inner file follows the **draft** BIP138 binary format pinned to [PR1951 source revision 5af62cba](https://github.com/pythcoiner/bips/blob/5af62cba9958a519218bcad8a0aae9e2090bb5bd/bip-0138.md). The supported writer payload is one public BIP380 multipath descriptor, 2–5 eligible account keys and five lexicographically sorted masks including random decoys. BullVault's public NUMS internal key is not a recipient. The reader checks binary bounds, canonical lengths, version, encryption algorithm, critical content types and authentication, then uses BDK to validate the policy and exact account membership. This is not a generic reader for every BIP138 descriptor set/content type.

The outer profile is **`bullvault-bip138-prototype-1`**, an experimental transport convention, not part of BIP138 or a registered Nostr standard. It wraps the entire BIP138 file separately for each recipient, concealing the inner masks from relay observers. All integers below are unsigned.

1. Decode and validate the public extended key. Canonical recovery material is `network_family_byte || compressed_public_key[33] || chain_code[32]`, where family is `0` for mainnet and `1` for test networks. Known public SLIP132 prefixes normalize to the same family. Ancestor fingerprint, depth and child index do not affect lookup. Private extended keys are rejected.
2. `tagged_hash(tag, bytes)` is SHA256(SHA256(UTF8(tag)) repeated twice || bytes). The lookup tag is lower-case hex of tagged_hash(profile + `/lookup`, material). The encryption key uses the separate tag profile + `/encryption`.
3. Plaintext is `uint32_be(file_length) || complete_BIP138_file || zero_padding` padded to a multiple of 4096 bytes. Encrypt with RFC8439 ChaCha20-Poly1305, a fresh nonzero random 12-byte nonce and AAD UTF8(profile + `:` + lookup).
4. Event content is `profile + ':' + base64(nonce || ciphertext || tag[16])`. Publish a regular experimental event of kind `1089`, with the single tag `['d', lookup]`. Event signing follows NIP01/BIP340. Each recipient has its own scoped author, derived by HMAC-SHA256 from the existing private publishing key over UTF8(profile + `/publisher`) || 0x00 || lookup_bytes || counter_byte. Start counter at zero; retry only if the digest is not a valid secp256k1 scalar.
5. Recovery queries `{"kinds":[1089],"#d":[lookup],"limit":32}` without an author filter. Validate event ID/signature, decrypt the outer layer, decrypt the BIP138 file using the account's x-only public key, then validate its descriptor. A descriptor key expression or single-key descriptor is accepted as input too.

Input must contain the actual cosigner account xpub, not a master xpub or a child xpub from which a hardened account cannot be reconstructed. Changing chain code or network family changes lookup. Child derivation/origin syntax is validated but is not part of the locator. The recovered descriptor retains the actual wallet policy, origins, receive/change paths and timelocks.

## Security and recovery limits

- An xpub is a **recovery capability** here. Anyone who obtains it can locate and decrypt this backup. Xpub-only decryption cannot keep it secret from that person. Hashing does not protect an xpub already known to an observer.
- The Nostr signing key is derived from private publishing material, not the xpub. This separates the three public authors and the ordinary metadata author. It does not prove wallet provenance to an xpub-only reader: an xpub holder can publish an altered policy under another author. Candidates remain explicitly unverified; this harness cannot import/fund them automatically.
- Padding and separate authors reduce direct linkage, but publication timing, network address, relay access logs, repeated lookup tags and size buckets can correlate activity. This prototype makes direct WebSocket connections.
- Signatures and both AEAD tags are verified locally. Malformed copies cannot suppress later valid copies merely by claiming the same event ID. Exact account public key and chain code must occur in the recovered policy.
- The client bounds input/decoded payloads, event counts, frames, connection time, retries and close handshakes. The WebSocket frame check happens **after** the library allocates a frame; this is not a hard network allocation limit. A native BDK parser crash and an in-progress worker's CPU cannot be cancelled by Dart.
- Cancellation prevents stale results and new sends but cannot retract accepted events. Partial publication can leave some copies public. Each attempt retries the exact signed event at most twice after the first try.
- EOSE ends one response, not a proof of global completeness or retention. AUTH/`more`, limits and timeouts leave results incomplete. Relays can omit, prune, censor or disappear. No latest-policy selection or 20-year retention guarantee exists. Preserve this profile/specification and independent readers before treating it as a durable recovery system.

## Run and verify

Use the repository-pinned FVM SDK. Run `make deps`, `make build-runner` and `make translations` for a new checkout. Test keys are deterministic and public. Run Flutter build/test commands sequentially within this checkout: concurrent invocations can overwrite the shared native-asset manifest and produce missing-FFI failures.

```sh
# Public relay round trip. Writes synthetic fixture/evidence to build/bip138-prototype/.
fvm flutter test test/features/bullvault/bip138_live_relay_test.dart \
  --dart-define=BIP138_LIVE=true --reporter expanded
# Optional alternate relay:
# --dart-define=BIP138_RELAY=wss://relay.damus.io

# Real UI recovery on a dedicated Android emulator, with no publishing identity.
fvm flutter test integration_test/bip138_nostr_prototype_test.dart \
  -d emulator-5582 --flavor beta --dart-define=BIP138_LIVE=true --reporter expanded

# Runnable app (integration-test APKs are not standalone apps).
fvm flutter run -d emulator-5582 --flavor beta -t tools/bip138_prototype_app.dart
# Add --dart-define=BIP138_RECOVERY_ONLY=true for manual empty-app recovery.

make checks
```

The live test distinguishes newly published event IDs from fetched event IDs. The emulator test enters each account xpub through the UI, retrieves from a real relay and compares receive/change addresses at indices 0, 7 and 111 against the original policy. Live tests are opt-in and normal unit tests do not publish.

Verification results and outstanding work are recorded in the companion `bip138-prototype-evidence.md`; commands above describe intended reproducibility, not a claim that an unexecuted check passed.
