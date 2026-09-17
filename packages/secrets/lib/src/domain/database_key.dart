import 'dart:typed_data';

import 'package:convert/convert.dart' as convert;
import 'package:meta/meta.dart';

/// The encryption key for one package's database.
///
/// Thirty-two random bytes. Not user material: it opens one local
/// database and nothing else. It cannot reach a seed, and it cannot open
/// another package's database.
///
/// Hand it to SQLCipher in **raw mode** — `PRAGMA key = "x'<hex>'"`,
/// which [pragma] spells for you. Passing [hex] as a bare string makes
/// SQLCipher treat it as a passphrase and run 256 000 PBKDF2 rounds over
/// an already-random key: pure loss, roughly 200 ms per database open.
@immutable
final class DatabaseKey {
  static const lengthInBytes = 32;

  /// The key's own copy. Private, because a key that shares a buffer with
  /// its caller is not a value: whoever passed the bytes in could change
  /// them afterwards, and every database opened with this key would move
  /// with them.
  final Uint8List _bytes;

  /// A read-only view on [_bytes]. Handing out the list itself would let
  /// a caller rewrite the key in place through the getter.
  Uint8List get bytes => _bytes.asUnmodifiableView();

  /// Refuses any other length in every build mode — an `assert` would
  /// let a truncated key through in release, and SQLCipher would accept
  /// it.
  ///
  /// The bytes are copied here, before anything can await: ownership is
  /// established at construction or not at all.
  factory DatabaseKey(Uint8List bytes) {
    if (bytes.length != lengthInBytes) {
      throw ArgumentError.value(
        bytes.length,
        'bytes',
        'a database key is $lengthInBytes bytes',
      );
    }
    return DatabaseKey._(Uint8List.fromList(bytes));
  }

  const DatabaseKey._(this._bytes);

  factory DatabaseKey.fromHex(String hex) =>
      DatabaseKey(Uint8List.fromList(convert.hex.decode(hex)));

  String get hex => convert.hex.encode(_bytes);

  /// The literal SQLCipher expects, raw-key form included.
  String get pragma => "x'$hex'";

  /// Never widen this: a key that prints itself ends up in a log.
  @override
  String toString() => 'DatabaseKey(•••)';
}
