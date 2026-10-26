/// The on-disk shape of a key this package holds on a module's behalf.
///
/// Unlike `SecretModel`, this format is **new** — nothing on a user's
/// device is written in it yet — so it carries the version and the
/// checks that the seed format never got a chance to.
///
/// ```json
/// {"v":1,"kind":"dek","name":"com.bullbitcoin.secrets/dek/swaps/main",
///  "bytes":"a3f1…","createdAt":"2026-09-14T10:42:00.000Z"}
/// ```
///
/// `name` repeats the storage key inside the value on purpose. On mobile
/// the OS keeps other applications out of our keystore, but on Linux and
/// Windows the session store has no per-application access control — any
/// process of the same user can move or rewrite an entry. Comparing the
/// two on read means a key that is not where it claims to be is refused
/// rather than used, which catches displacement and clumsy tampering.
/// It does not stop an attacker who rewrites both; nothing at this layer
/// can, and such an attacker has already read the seed next to it.
///
/// This type *compares* the key; it does not compose one. Where a value
/// lives is a storage concern, so the namespace and the composer belong
/// to `FlutterSecureStorageDatasource`, which passes the key it read
/// from as `expectedName`.
library;

import 'package:meta/meta.dart';

/// What a stored key is for. The first segment of its storage key, and a field of its envelope; a read refuses a key of another kind.
///
/// An enum so that the set of kinds is closed and a typo is a compile error, with the wire name kept apart so that adding a kind never renames one already on disk.
enum KeyKind {
  /// A database encryption key handed to another module.
  dek('dek');

  const KeyKind(this.wire);

  /// The exact string written to the keystore, in the key path and in the envelope. Frozen.
  final String wire;

  /// Refuses an unknown name with a fixed message — the value is stored content and is never quoted.
  static KeyKind parse(Object? value) {
    for (final kind in values) {
      if (kind.wire == value) return kind;
    }
    throw const FormatException('unknown key kind');
  }
}

class KeyModel {
  static const _kVersion = 'v';
  static const _kKind = 'kind';
  static const _kName = 'name';
  static const _kBytes = 'bytes';
  static const _kCreatedAt = 'createdAt';

  static const currentVersion = 1;

  final int version;

  /// What the key is for. Lets a read refuse to hand a signing key to something asking for an encryption key.
  final KeyKind kind;

  /// The full storage key this value expects to be filed under.
  final String name;

  final String bytesHex;
  final DateTime createdAt;

  @internal
  const KeyModel({
    required this.version,
    required this.kind,
    required this.name,
    required this.bytesHex,
    required this.createdAt,
  });

  @internal
  KeyModel.dek({
    required this.name,
    required this.bytesHex,
    required this.createdAt,
  }) : version = currentVersion,
       kind = KeyKind.dek;

  Map<String, dynamic> toJson() => {
    _kVersion: version,
    _kKind: kind.wire,
    _kName: name,
    _kBytes: bytesHex,
    _kCreatedAt: createdAt.toUtc().toIso8601String(),
  };

  /// Rejects anything that is not exactly what was asked for.
  ///
  /// [expectedName] and [expectedKind] are what the caller looked up; a
  /// mismatch means the value moved, or was never ours.
  @internal
  factory KeyModel.fromJson(
    Map<String, dynamic> json, {
    required String expectedName,
    required KeyKind expectedKind,
  }) {
    // Fixed strings only. The stored fields are untrusted — on Linux and
    // Windows any process of the same user can write them — and a message
    // that quoted one would carry that content into a failure, and from
    // there into logs. `expectedKind` and `expectedName` are ours, but
    // the rule is simpler to audit with no interpolation at all.
    final version = json[_kVersion];
    // `is! int` first: `1.0 == 1` holds for Dart numbers, and the cast below would then throw a `TypeError` — a programmer error — for what is malformed stored input.
    if (version is! int || version != currentVersion) {
      throw const FormatException('unsupported key version');
    }
    final kind = KeyKind.parse(json[_kKind]);
    if (kind != expectedKind) {
      throw const FormatException('key kind does not match the one asked for');
    }
    final name = json[_kName];
    if (name != expectedName) {
      throw const FormatException('key name does not match where it was read');
    }
    return KeyModel(
      version: version,
      kind: kind,
      name: name as String,
      bytesHex: _bytesHex(json[_kBytes]),
      createdAt: _createdAt(json[_kCreatedAt]),
    );
  }

  /// The key itself, checked here rather than two layers down.
  ///
  /// Left to `DatabaseKey`, a truncated or non-hex value surfaced as an
  /// `ArgumentError` or a bare `FormatException` from `hex.decode`, far
  /// from the read that produced it — and `hex.decode` puts the offending
  /// input in its message. Neither the length nor the alphabet is a
  /// property of `DatabaseKey` alone: a stored value that is not 64 hex
  /// characters was never one of ours.
  static String _bytesHex(Object? value) {
    if (value is! String) {
      throw FormatException('"$_kBytes" must be a string');
    }
    if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(value)) {
      throw const FormatException('"bytes" is not hexadecimal');
    }
    if (value.length != _expectedHexLength) {
      throw const FormatException('"bytes" is not 32 bytes');
    }
    return value;
  }

  /// 32 bytes, two hex characters each. Spelled here rather than read
  /// from `DatabaseKey` so that `data/` keeps no dependency on the shape
  /// of a domain type it only ever stores.
  static const _expectedHexLength = 64;

  static DateTime _createdAt(Object? value) {
    if (value is! String) {
      throw FormatException('"$_kCreatedAt" must be a string');
    }
    final parsed = DateTime.tryParse(value);
    // `DateTime.parse` quotes its input; this one does not.
    if (parsed == null) {
      throw const FormatException('"createdAt" is not an ISO-8601 date');
    }
    return parsed;
  }
}
