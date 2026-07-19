import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/features/invoices/data/models/private_invoice_presentation_model.dart';
import 'package:bb_mobile/features/invoices/domain/entities/encrypted_private_invoice.dart';
import 'package:bb_mobile/features/invoices/domain/entities/private_invoice_presentation.dart';
import 'package:bb_mobile/features/invoices/domain/private_invoice_cipher.dart';
import 'package:cryptography/cryptography.dart';

typedef PrivateInvoiceRandomBytes = List<int> Function(int length);

class PrivateInvoiceCipherImpl implements PrivateInvoiceCipher {
  static const _aad = 'bullnym-private-invoice-presentation-v1';
  static const _frameBytes = 4096;

  final AesGcm _cipher;
  final PrivateInvoiceRandomBytes _randomBytes;

  PrivateInvoiceCipherImpl({
    AesGcm? cipher,
    PrivateInvoiceRandomBytes? randomBytes,
  }) : _cipher = cipher ?? AesGcm.with256bits(),
       _randomBytes = randomBytes ?? _secureRandomBytes;

  @override
  String newClientRequestId() => _uuidV4(_randomBytes(16));

  @override
  Future<EncryptedPrivateInvoice> encrypt(
    PrivateInvoicePresentation presentation,
  ) async {
    final model = PrivateInvoicePresentationModel.fromEntity(presentation);
    final jsonBytes = utf8.encode(jsonEncode(model.value));
    if (jsonBytes.isEmpty ||
        jsonBytes.length > privateInvoicePresentationMaxJsonBytes) {
      throw const PrivateInvoicePresentationException(
        field: 'presentation',
        code: 'too_large',
      );
    }

    final frame = Uint8List(_frameBytes);
    frame[0] = jsonBytes.length >> 8;
    frame[1] = jsonBytes.length & 0xff;
    frame.setRange(2, 2 + jsonBytes.length, jsonBytes);
    final padding = _randomBytes(_frameBytes - 2 - jsonBytes.length);
    frame.setRange(2 + jsonBytes.length, _frameBytes, padding);

    final keyBytes = _randomBytes(32);
    final nonce = _randomBytes(12);
    final box = await _cipher.encrypt(
      frame,
      secretKey: SecretKey(keyBytes),
      nonce: nonce,
      aad: utf8.encode(_aad),
    );
    if (box.cipherText.length != _frameBytes || box.mac.bytes.length != 16) {
      throw StateError('private invoice cipher returned an invalid shape');
    }
    final envelope = Uint8List(1 + 12 + _frameBytes + 16)
      ..[0] = 1
      ..setRange(1, 13, nonce)
      ..setRange(13, 13 + _frameBytes, box.cipherText)
      ..setRange(13 + _frameBytes, 1 + 12 + _frameBytes + 16, box.mac.bytes);

    return EncryptedPrivateInvoice(
      clientRequestId: newClientRequestId(),
      presentationEnvelope: base64Url.encode(envelope).replaceAll('=', ''),
      viewingKey: base64Url.encode(keyBytes).replaceAll('=', ''),
    );
  }

  static List<int> _secureRandomBytes(int length) {
    final random = SecureRandom.defaultRandom;
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  static String _uuidV4(List<int> source) {
    if (source.length != 16) throw ArgumentError.value(source.length, 'source');
    final bytes = Uint8List.fromList(source);
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
