# One BIP85-derived password, two separate backups

Status: standalone prototype on `distributed-resiliant-backups`, revised 2026-09-09 to reuse the existing RecoverBull encryptor at the user’s request. [The prototype document](portable-backup-prototype.md) specifies its exact bytes, derivations, runnable entrypoint and validation. This draft describes the wider integration work still required.

## Confirmed decisions

- Derive a valid 12-word English BIP39 backup password from the original BULL seed through an existing reserved BIP85 path. Display it in a protected UI for the user to record. Do not generate an unrelated wallet or ask for cold signer seeds.
- The same password unlocks two separate files: full supported metadata, including vault data, and a standalone complete BullVault descriptor. The vault file requires no hidden xpub or second credential.
- Password alone must suffice to derive the Nostr lookup/signing identity. Do not derive it from the original mobile seed or from per-file randomness. Sharing the password shares backup read/write authority, not Bitcoin spending keys.
- Only the separate vault artifact goes to Nostr and eventually Bitcoin. Metadata stays on the backup server and in exported files.
- Preserve a descriptor-only recovery path with no automatic metadata import or wallet overwrite.
- The eventual Bitcoin addon uses one transaction and one OP_RETURN containing the full encrypted descriptor; deterministic discovery must work from the password. This changes the earlier xpub-based design and is not implemented by the portable-backup slice.

## Prototype scope

The prototype uses `m/83696968'/1642'/0'/1'`, the existing `walletBackupEncryptionKey` reservation. Full 64-byte BIP85 entropy is domain-separated with HKDF before encoding 16 bytes as 12 BIP39 words. It does not expose the first 16 bytes of the legacy metadata encryption key. HKDF-SHA256 of the mnemonic entropy with the documented `encryption-v1` context gives the 32-byte RecoverBull encryption key. Each file has a fresh random IV. The Nostr identity is deterministically derived from that encryption key through the separate `nostr-auth-v1` context.

The standalone app creates two encrypted synthetic fixture files, publishes only the vault, fetches it from a real Nostr relay using the password, and locally unlocks the metadata file. It does not initialize production wallet storage or activate automatic backup. The existing legacy resolver, metadata format, main-seed Nostr identities and BIP138/xpub protocol remain readable and unchanged. The new portable artifact is not BIP138 wire-compatible.

## Production integration still to design and test

1. **Metadata identity and server protocol.** Introduce an explicit versioned credential/profile namespace. Verify server authentication, fetch/store/delete and CAS behavior against the actual backend. A new identity must not silently replace legacy recovery access. An old client must not overwrite a head it cannot decrypt; CAS by itself does not solve that.
2. **Credential lifecycle.** Regenerate from the original seed at point of use; persist only justified status. Keep words within the sealed secret UI and operation scope. Require recording/confirmation before activating new automatic writers. Handle authentication cancellation, screen protection failure, backgrounding and disposal without stale callbacks.
3. **Metadata recovery ownership.** Reuse the canonical snapshot codec, validation and preview/import flow. Validate source ownership and supported versions before writes. Wrong password, unknown format, malformed files and network failures must not trigger a legacy-key fallback or partial import.
4. **Two server artifacts.** Store metadata and the vault independently, with authenticated purpose/network binding. Fetching a descriptor must neither require metadata bytes nor restore unrelated settings. Keep source selection and retries explicit.
5. **Nostr durability.** Add bounded pagination and multiple configured relays if required for full history. Preserve authentic older generations; do not trust relay completeness or timestamps as authoritative vault state. Specify event retention and identity lifecycle without promising permanent storage.
6. **Bitcoin discovery.** Specify a password-derived marker key/address and canonical network/path convention, payload framing, fees and publication UX. Reuse the existing Electrum/history/raw transaction components. Validate a real single-OP_RETURN testnet4 transaction and fresh password-only retrieval before enabling this profile.
7. **Migration and rollback.** Keep old formats and identities available. Separate user confirmation, local activation and actual upload success. Fence unsupported or unreadable remote heads durably across restart and retries. Test all settings, wizard, automatic-job and recovery consumers before changing production defaults.

## Security tradeoffs

The 12 words carry 128 bits of entropy plus checksum. They inherit parent-seed compromise or weak randomness; a child derivation cannot repair either. Someone with the password can decrypt both artifacts and sign backup events. A read-only sharing credential would require a different design.

Public encrypted backups disclose size, timing and a stable publication identity. Relays can correlate requests with IP addresses, omit or replay data, and disappear. RecoverBull authenticates contents but does not provide rollback protection or guarantee future availability. Bitcoin storage preserves ciphertext under Bitcoin's own availability assumptions; discovery still needs implemented scanning/indexing conventions.

## Work checklist

- [x] Record the user's shared-password and separate-artifact decisions.
- [x] Implement bounded RecoverBull-encrypted files and reserved-path credential derivation in a standalone prototype.
- [x] Implement password-derived Nostr identity and vault-only publication checks.
- [x] Complete RecoverBull interoperability, full host checks, fresh Nostr emulator recovery, security and simplification review; see the prototype verification record.
- [ ] Design and implement production metadata/server migration in separately reviewable chunks.
- [ ] Implement and test password-derived Bitcoin publication/discovery.
- [ ] Integrate production settings and actual restore flows, then repeat device/security reviews.
