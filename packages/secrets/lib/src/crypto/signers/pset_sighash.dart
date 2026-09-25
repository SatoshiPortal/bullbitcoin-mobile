import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:secrets/src/crypto/exceptions.dart';

/// Refuses, before lwk sees it, a PSET that asks for anything but `SIGHASH_ALL`.
///
/// lwk_signer 0.18.0 signs each input it owns with the `sighash_type` written *in that input* (`software.rs`, `SwSigner::sign`: `input.sighash_type.map(..).unwrap_or(All)`). Whoever authored the PSET therefore chooses what our signature commits to: `NONE` commits to no output, `SINGLE` to one, `ANYONECANPAY` to no other input — each lets a counterparty take the input's value somewhere the user never saw. The Bitcoin signer closes the same door with bdk's `allowAllSighashes: false`; lwk exposes no such option, so the check lives here.
///
/// A PSET lwk builds for this app leaves the field absent, which means `ALL`. Only LiquiDEX makers ask for `SINGLE|ANYONECANPAY`, and the app makes none.
///
/// Reads the PSET v2 key-value maps (BIP 370 framing, Elements keys) far enough to find every input's `PSBT_IN_SIGHASH_TYPE` and nothing else. Anything it cannot read is refused: this runs on counterparty-authored bytes, and a PSET lwk would parse but this cannot is not one to sign blind.
@internal
abstract final class PsetSighash {
  static const _all = 0x01;
  static const _globalInputCount = 0x04;
  static const _globalOutputCount = 0x05;
  static const _inSighashType = 0x03;
  static const _magic = [0x70, 0x73, 0x65, 0x74, 0xff]; // "pset" 0xff

  /// Throws [LiquidSigningFailed] unless every input's sighash is absent or `SIGHASH_ALL`.
  static void requireAll(String psetBase64) {
    final List<int?> types;
    try {
      types = sighashTypes(psetBase64);
    } on FormatException {
      throw const LiquidSigningFailed();
    }
    if (types.any((t) => t != null && t != _all)) {
      throw const LiquidSigningFailed();
    }
  }

  /// The sighash type each input asks for, in input order; `null` when absent.
  ///
  /// Throws [FormatException] (fixed messages, never PSET bytes) on anything that is not a well-formed PSET v2.
  @visibleForTesting
  static List<int?> sighashTypes(String psetBase64) {
    final Uint8List bytes;
    try {
      bytes = base64.decode(psetBase64.trim());
    } on FormatException {
      throw const FormatException('PSET is not base64');
    }
    final r = _Reader(bytes);
    for (final b in _magic) {
      if (r.byte() != b) throw const FormatException('not a PSET');
    }

    int? inputs;
    int? outputs;
    for (final (type, value) in r.map()) {
      if (type == _globalInputCount) {
        inputs = _Reader(value).fullCompactSize();
      }
      if (type == _globalOutputCount) {
        outputs = _Reader(value).fullCompactSize();
      }
    }
    if (inputs == null || outputs == null) {
      throw const FormatException('PSET has no input or output count');
    }

    final types = <int?>[];
    for (var i = 0; i < inputs; i++) {
      int? sighash;
      for (final (type, value) in r.map()) {
        if (type != _inSighashType) continue;
        if (sighash != null || value.length != 4) {
          throw const FormatException('malformed input sighash');
        }
        sighash = ByteData.sublistView(value).getUint32(0, Endian.little);
      }
      types.add(sighash);
    }
    for (var o = 0; o < outputs; o++) {
      r.map().length;
    }
    if (!r.atEnd) throw const FormatException('trailing bytes after PSET');
    return types;
  }
}

/// A bounds-checked cursor; every overrun is a [FormatException].
final class _Reader {
  final Uint8List _bytes;
  int _at = 0;

  _Reader(this._bytes);

  bool get atEnd => _at == _bytes.length;

  int byte() {
    if (_at >= _bytes.length) throw const FormatException('truncated PSET');
    return _bytes[_at++];
  }

  Uint8List take(int n) {
    if (n < 0 || _at + n > _bytes.length) {
      throw const FormatException('truncated PSET');
    }
    final out = Uint8List.sublistView(_bytes, _at, _at + n);
    _at += n;
    return out;
  }

  int compactSize() {
    final first = byte();
    int wide(int n) {
      var v = 0;
      for (var i = 0; i < n; i++) {
        v |= byte() << (8 * i);
      }
      return v;
    }

    final value = switch (first) {
      < 0xfd => first,
      0xfd => wide(2),
      0xfe => wide(4),
      _ => wide(8),
    };
    if (value < 0) throw const FormatException('implausible PSET size');
    return value;
  }

  /// A length or a count: bounded by what is left, so a forged size cannot make the reader loop or allocate.
  int size() {
    final value = compactSize();
    if (value > _bytes.length - _at) {
      throw const FormatException('implausible PSET size');
    }
    return value;
  }

  int fullCompactSize() {
    final v = compactSize();
    if (!atEnd) throw const FormatException('malformed PSET count');
    return v;
  }

  /// One key-value map up to its `0x00` separator, as (key type, value) pairs.
  List<(int, Uint8List)> map() {
    final entries = <(int, Uint8List)>[];
    while (true) {
      final keyLength = size();
      if (keyLength == 0) return entries;
      final key = _Reader(take(keyLength));
      final type = key.compactSize();
      final value = take(size());
      entries.add((type, value));
    }
  }
}
