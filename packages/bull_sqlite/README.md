# bull_sqlite

Local SQLite databases encrypted at rest with [SQLite3MultipleCiphers](https://utelle.github.io/SQLite3MultipleCiphers/), for the packages that own one. Pure Dart.

## ⚠️ What is not covered

Only databases opened through this package are encrypted: today the app's `bullbitcoin_sqlite.sqlite` and `payjoin.sqlite`. The stores that wallet libraries keep next to them are written by native code this package does not reach, and stay as their library writes them:

| Store | Library | Path | Contents in clear |
|---|---|---|---|
| BDK wallet | bdk_dart / bdk_wallet (SQLite) | `Documents/<hex(walletId)>_bdk_dart` | transactions, UTXOs, addresses, public descriptors |
| LWK cache | lwk_wollet | `Documents/<hex(walletId)>/<network>/enc_cache/…` | encrypted by LWK with a key derived from the confidential descriptor; file names in clear |
| Silent Payments account | bwk (SQLite) | `Documents/sp/account.sqlite`, `Documents/sp/sp-sub-0/account.sqlite` | transactions, outputs with their tweak and label scalars |
| Silent Payments headers | bwk | `Documents/sp/headers.bin` | public block headers |

None of them holds a spending key, a mnemonic, a seed or an xprv (audited 2026-11-12 against bull_sdk `1b01dc5e`). The BDK and LWK file names contain the wallet's master fingerprint. The price cache `pricer.sqlite` holds public data and is not encrypted either.

## What it does

- `SqliteCipher.key` / `configure`: keys a connection before anything else runs on it, with a raw 32-byte key (`DatabaseKey` from `primitives`, generated and kept by `secrets`) and an explicitly named cipher (`chacha20`). A library without a cipher is refused rather than used in clear. `PRAGMA key` accepts any key, so a read proves it.
- `EncryptedSqlite.inspect`: classifies a database's whole family of files (`-wal`, `-shm`, `-journal`, encryption candidate, retirement marker) from lengths and headers, without opening or deleting anything.
- `EncryptedSqlite.encrypt`: encrypts a plaintext database in place, by one atomic replace (below).
- `EncryptedSqlite.open` / `probe` / `userVersion`: open an encrypted database, always after a durability barrier on its directory.
- `EncryptedSqlite.retire`: deletes or quarantines a whole family, resumably.

It decides nothing about keys: whether a missing key may be created is the owner's call (`features/local_data` for the app's databases).

## Crash model

Encryption of a plaintext database:

1. The source is opened, recovered by SQLite, checked, and moved to `journal_mode=DELETE` with `synchronous=FULL`: no WAL or hot journal remains, and the file is synced.
2. `VACUUM INTO` writes a copy (the candidate), which `PRAGMA rekey` encrypts.
3. The candidate is reopened with the key and compared with the source: integrity, `user_version`, schema and every row.
4. The candidate is flushed, renamed over the source, and the directory is synced.

The rename is the commit point. Before it, the plaintext database is untouched and the candidate is only a copy, discarded by the next attempt once the source is proven intact. After it, the database is encrypted. Dart cannot sync a directory, so this package calls `open`/`fsync`/`close` through FFI; every open repeats that barrier, so nothing writes to a database whose publication is not yet durable. A power loss before the barrier may bring back the plaintext database and its candidate, and the next start encrypts again.

Retirement writes a marker before touching any member and removes it last, each step followed by a barrier; an interrupted retirement is finished as decided before anything opens. Deleting a file does not erase its old pages from flash storage.

Only one process side may encrypt or retire: the foreground app. Background work must not open these databases while that can happen.
