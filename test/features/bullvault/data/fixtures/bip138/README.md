# Pinned upstream BIP138 fixtures

`encrypted_backup.json` and `bip-0138.md` were copied from `pythcoiner/bips` at commit `5af62cba9958a519218bcad8a0aae9e2090bb5bd` (the BIP138 proposal in bitcoin/bips PR1951).

- [Specification](https://github.com/pythcoiner/bips/blob/5af62cba9958a519218bcad8a0aae9e2090bb5bd/bip-0138.md)
- [Vectors](https://github.com/pythcoiner/bips/blob/5af62cba9958a519218bcad8a0aae9e2090bb5bd/bip-0138/test_vectors/encrypted_backup.json)

The specification includes its BSD-2-Clause copyright/license notice. These are upstream public test fixtures, not user wallet data. The test evaluates all seven vectors, including the invalid zero-nonce case; it does not regenerate them with the implementation under test.
