import 'package:meta/meta.dart';

import 'package:secrets/src/domain/secrets_error.dart';
import 'package:secrets/src/domain/value_objects/mnemonic_length.dart';

/// BIP85 application, mirroring the SDK app-numbers used across the codebase.
enum Bip85Application {
  bip39(39),
  hex(128169),
  recoverbull(1608);

  const Bip85Application(this.number);
  final int number;

  static Bip85Application fromNumber(int number) =>
      Bip85Application.values.firstWhere(
        (a) => a.number == number,
        orElse: () => throw UnknownBip85ApplicationError(
            'Unknown BIP85 application number', 'number'),
      );
}

/// A BIP85 derivation path, APP-ROOTED (first element is the application number,
/// e.g. `39'/0'/12'/0'`). Round-trips with or without a leading `m/`, and also
/// accepts an ABSOLUTE path — a leading `83696968'` (the reserved BIP85 root
/// purpose) is stripped so `appNumber`/`index` read the application, not the
/// root. Without this, `m/83696968'/39'/…` would report `appNumber == 83696968`
/// and label/derive the wrong secret.
@immutable
class Bip85Path {
  /// The reserved BIP85 root purpose (`m/83696968'`), omitted by the app-rooted
  /// form the package uses everywhere.
  static const _rootPurpose = "83696968'";

  factory Bip85Path(String path) {
    var normalized = path.startsWith('m/') ? path.substring(2) : path;
    if (normalized.startsWith('$_rootPurpose/')) {
      normalized = normalized.substring(_rootPurpose.length + 1);
    }
    if (normalized.isEmpty || !normalized.contains('/')) {
      throw InvalidBip85PathError('invalid BIP85 path', 'path');
    }
    // Validate EVERY segment eagerly (the value-object precondition model): a
    // malformed persisted path fails HERE, at construction, instead of parsing
    // fine and detonating later in a display/derivation getter. `_segmentInt`
    // rejects a non-numeric/negative/over-2^31 segment (e.g. `"5'8'"`, `" -39'"`).
    for (final seg in normalized.split('/')) {
      _segmentInt(seg);
    }
    return Bip85Path._(normalized);
  }
  const Bip85Path._(this.path);

  /// The path WITHOUT a leading `m/`.
  final String path;

  /// First path element (the application number).
  int get appNumber => _segmentInt(path.split('/').first);

  /// Last path element (the index).
  int get index => _segmentInt(path.split('/').last);

  /// Parses a hardened path segment (`"128169'"` → `128169`) into an int,
  /// surfacing a malformed stored path as the typed [InvalidBip85PathError]
  /// rather than a raw `FormatException` a caller can't distinguish.
  ///
  /// Strict per-segment shape: digits with an OPTIONAL single trailing hardened
  /// marker. A blanket `replaceAll("'", "")` + `int.tryParse` would accept
  /// `"'12'"` → 12 and `"-1'"` → -1, silently constructing a DIFFERENT path
  /// identity (breaking `==`/dedup and mislabeling the derived secret). Every
  /// BIP85 element is hardened, so the value is also bounded to [0, 2^31).
  static int _segmentInt(String segment) {
    final m = RegExp(r"^(\d+)'?$").firstMatch(segment);
    final n = m == null ? null : int.tryParse(m.group(1)!);
    if (n == null || n >= 0x80000000) {
      throw InvalidBip85PathError('invalid BIP85 path segment', 'path');
    }
    return n;
  }

  @override
  bool operator ==(Object other) => other is Bip85Path && other.path == path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'Bip85Path($path)';
}

/// A derived child mnemonic — the sealed display payload for `Bip85MnemonicView`.
///
/// The derived [words] are SECRET. They are marked `@internal` so the sealed
/// view (in-package) can render them while any external read trips the seal
/// lint. `toString` is redacted; there is no `toJson`.
@immutable
class Bip85Derivation {
  const Bip85Derivation({
    required this.path,
    required this._words,
    this.length,
  });

  final Bip85Path path;
  final MnemonicLength? length;

  final List<String> _words;

  /// SECRET — for the sealed `Bip85MnemonicView` only. Not part of the public
  /// API; external use trips `invalid_use_of_internal_member`.
  @internal
  List<String> get words => List.unmodifiable(_words);

  @override
  String toString() => 'Bip85Derivation(${path.path}, '
      'length: ${length?.words})'; // words intentionally omitted
}

/// A derived hex secret — the sealed display payload for `Bip85HexView`.
@immutable
class Bip85HexResult {
  const Bip85HexResult({required this.path, required this._hex});

  final Bip85Path path;
  final String _hex;

  /// SECRET — for the sealed `Bip85HexView` only.
  @internal
  String get hexForView => _hex;

  @override
  String toString() => 'Bip85HexResult(${path.path}, ${_hex.length ~/ 2} bytes)';
}
