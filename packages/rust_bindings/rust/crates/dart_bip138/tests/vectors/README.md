# Official BIP138 test vectors

Vendored unchanged using `gh api` raw content from bitcoin/bips commit `299442b7ded6c58c64fce45f6972795a2d9f3109`, directory `bip-0138/test_vectors/`, on 2026-11-20. This pins the official BIP138 vectors used by the backup design. This commit does not contain a BIP139 specification, so it cannot also pin the BIP139 schema. These are public specification fixtures, never wallet data. Source: https://github.com/bitcoin/bips/tree/299442b7ded6c58c64fce45f6972795a2d9f3109/bip-0138/test_vectors

Tests exercise v1 wire/crypto vectors and supported miniscript-12 recipient vectors. MuSig and policy backup parsing are outside the enabled dependency features. BIP380 document vectors are retained for provenance, but its optional descriptor_backup parser is intentionally disabled.
