import 'package:bb_mobile/features/labels/domain/primitive/label_type.dart';
import 'package:bs58check/bs58check.dart' as base58;
import 'package:convert/convert.dart';

class LabelEntity {
  final int? id;
  final LabelType type;
  final String label;
  final String reference;
  final String? origin;

  LabelEntity({
    this.id,
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
      case LabelType.input:
        final parts = reference.split(':');
        _validateTxid(parts[0]);
        _validateIndex(parts[1]);

      case LabelType.output:
        final parts = reference.split(':');
        _validateTxid(parts[0]);
        _validateIndex(parts[1]);
      case LabelType.extendedPublicKey:
        _validateExtendedPublicKeyReference();
    }
  }

  void _validateTxid(String input) {
    if (reference.length != 64) {
      throw LabelValidationException(
        'Invalid transaction reference: must be 64 hex characters',
      );
    }

    try {
      hex.decode(reference);
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
