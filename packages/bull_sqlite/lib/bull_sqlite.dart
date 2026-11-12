/// Local SQLite databases encrypted at rest with SQLite3MultipleCiphers.
///
/// ⚠️ Covers only the databases opened through it. Wallet libraries keep their own stores (BDK, LWK, Silent Payments), written by native code, which stay as their library writes them — see the README.
library;

export 'src/encrypted_sqlite.dart' show EncryptedSqlite;
export 'src/retire.dart'
    show Retirement, DeleteRetirement, QuarantineRetirement;
export 'src/sqlite_cipher.dart' show SqliteCipher;
export 'src/sqlite_family.dart' show SqliteFileState;
export 'src/sqlite_storage_failure.dart';
