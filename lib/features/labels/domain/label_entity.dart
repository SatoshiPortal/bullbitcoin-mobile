import 'package:bb_mobile/features/labels/domain/primitive/label_type.dart';
import 'package:bs58check/bs58check.dart' as base58;
import 'package:convert/convert.dart';

class LabelEntity {
  final int id;
  final LabelType type;
  final String label;
  final String reference;
  final String? origin;

  LabelEntity({
    required this.id,
    required this.type,
    required this.label,
    required this.reference,
    this.origin,
  }) {
    _validateReference();
  }

  void _validateReference() {
    switch (type) {
      case LabelType.transaction:
        _validateTxid(reference);
      case LabelType.address:
        // Address validation requires async BDK/LWK calls
        break;
      case LabelType.publicKey:
        // Per BIP-329 a pubkey record's ref IS a public key (the codec maps
        // PubkeyLabel.ref straight through) — never a txid:vout like
        // input/output below.
        _validatePublicKey(reference);
      case LabelType.input:
        _validateOutPoint(reference);
      case LabelType.output:
        _validateOutPoint(reference);
      case LabelType.extendedPublicKey:
        _validateExtendedPublicKeyReference();
    }
  }

  void _validateTxid(String input) {
    // Validates the passed slice, not the full `reference` field: for
    // LabelType.input/output/publicKey, reference is `txid:vout` and would
    // never pass a 64-hex-char check on its own — every well-formed label
    // of those three types was being rejected unconditionally before this
    // fix (the txid slice was already split out by the caller into
    // `input`, but validation looked at the untouched full field instead).
    if (input.length != 64) {
      throw LabelValidationException(
        'Invalid transaction reference: must be 64 hex characters',
      );
    }

    try {
      hex.decode(input);
    } catch (e) {
      throw LabelValidationException(
        'Invalid transaction reference: must be valid hex',
      );
    }
  }

  void _validateIndex(String input) {
    final index = int.tryParse(input);
    if (index == null || index < 0) {
      throw LabelValidationException(
        'Invalid index reference: must be a non-negative integer',
      );
    }
  }

  /// Validates a `txid:vout` outpoint reference (BIP-329 input/output
  /// records). A missing separator throws [LabelValidationException] instead
  /// of a RangeError from indexing the split.
  void _validateOutPoint(String input) {
    final parts = input.split(':');
    if (parts.length != 2) {
      throw LabelValidationException(
        'Invalid outpoint reference: must be txid:vout',
      );
    }
    _validateTxid(parts[0]);
    _validateIndex(parts[1]);
  }

  /// Validates a public key reference (BIP-329 pubkey records): hex-decodable
  /// and a plausible key length — 64 chars (x-only), 66 (compressed), or
  /// 130 (uncompressed).
  void _validatePublicKey(String input) {
    const validLengths = {64, 66, 130};
    if (!validLengths.contains(input.length)) {
      throw LabelValidationException(
        'Invalid public key reference: must be 64, 66 or 130 hex characters',
      );
    }
    try {
      hex.decode(input);
    } catch (e) {
      throw LabelValidationException(
        'Invalid public key reference: must be valid hex',
      );
    }
  }

  /// Validates extended public key reference by decoding base58 and checking length
  /// Extended keys (xpub, ypub, zpub, tpub, etc.) are 78 bytes when decoded
  void _validateExtendedPublicKeyReference() {
    try {
      final decoded = base58.decode(reference);
      if (decoded.length != 78) {
        throw LabelValidationException(
          'Invalid extended public key reference: decoded length must be 78 bytes, got ${decoded.length}',
        );
      }
    } catch (e) {
      if (e is LabelValidationException) rethrow;
      throw LabelValidationException(
        'Invalid extended public key reference: failed to decode base58 - $e',
      );
    }
  }
}

class LabelValidationException implements Exception {
  final String message;

  LabelValidationException(this.message);

  @override
  String toString() => 'LabelValidationException: $message';
}
