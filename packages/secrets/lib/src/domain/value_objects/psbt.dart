import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:secrets/src/domain/secrets_error.dart';

bool _isBase64(String s) {
  if (s.isEmpty) return false;
  try {
    base64.decode(base64.normalize(s));
    return true;
  } catch (_) {
    return false;
  }
}

/// An unsigned PSBT/PSET as base64. The real cross-boundary type for partially
/// signed transactions is a base64 `String`; this is a thin validating wrapper.
/// NON-secret (a PSBT is meant to be shared between signers).
@immutable
class Psbt {
  factory Psbt(String base64Value) {
    if (!_isBase64(base64Value)) {
      throw InvalidPsbtError('invalid base64 PSBT', 'base64');
    }
    return Psbt._(base64Value);
  }
  const Psbt._(this.base64);

  final String base64;

  @override
  bool operator ==(Object other) => other is Psbt && other.base64 == base64;

  @override
  int get hashCode => base64.hashCode;

  @override
  String toString() => 'Psbt(${base64.length} b64 chars)';
}

/// A signed PSBT/PSET as base64 — the output of a [SignerPort] operation.
@immutable
class SignedPsbt {
  factory SignedPsbt(String base64Value) {
    if (!_isBase64(base64Value)) {
      throw InvalidPsbtError('invalid base64 signed PSBT', 'base64');
    }
    return SignedPsbt._(base64Value);
  }
  const SignedPsbt._(this.base64);

  final String base64;

  @override
  bool operator ==(Object other) =>
      other is SignedPsbt && other.base64 == base64;

  @override
  int get hashCode => base64.hashCode;

  @override
  String toString() => 'SignedPsbt(${base64.length} b64 chars)';
}
