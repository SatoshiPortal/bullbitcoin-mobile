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
        _validatePublicKeyReference();
      case LabelType.input:
      case LabelType.output:
        final parts = reference.split(':');
        if (parts.length != 2) {
          throw LabelValidationException(
            'Invalid outpoint reference: expected txid:index',
          );
        }
        _validateTxid(parts[0]);
        _validateIndex(parts[1]);
      case LabelType.extendedPublicKey:
        _validateExtendedPublicKeyReference();
    }
  }

  void _validateTxid(String input) {
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

  void _validatePublicKeyReference() {
    try {
      final decoded = hex.decode(reference);
      final isXOnly = decoded.length == 32;
      final isCompressed =
          decoded.length == 33 && (decoded.first == 2 || decoded.first == 3);
      final isUncompressed = decoded.length == 65 && decoded.first == 4;
      if (!isXOnly && !isCompressed && !isUncompressed) {
        throw LabelValidationException(
          'Invalid public key reference: expected a 32, 33, or 65 byte key',
        );
      }
    } catch (e) {
      if (e is LabelValidationException) rethrow;
      throw LabelValidationException(
        'Invalid public key reference: must be valid hex',
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
      final keyPrefix = decoded[45];
      if (keyPrefix != 2 && keyPrefix != 3) {
        throw LabelValidationException(
          'Invalid extended public key reference: expected public key data',
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
