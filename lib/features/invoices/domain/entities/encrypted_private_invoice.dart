class EncryptedPrivateInvoice {
  static final RegExp _base64Url = RegExp(r'^[A-Za-z0-9_-]+$');
  static final RegExp _uuidV4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  final String clientRequestId;
  final String presentationEnvelope;
  final String viewingKey;

  EncryptedPrivateInvoice({
    required this.clientRequestId,
    required this.presentationEnvelope,
    required this.viewingKey,
  }) {
    if (!_uuidV4.hasMatch(clientRequestId)) {
      throw ArgumentError.value(clientRequestId, 'clientRequestId');
    }
    if (presentationEnvelope.length != 5500 ||
        !_base64Url.hasMatch(presentationEnvelope)) {
      throw ArgumentError.value(
        '<redacted>',
        'presentationEnvelope',
        'must be a canonical private-invoice-v1 envelope',
      );
    }
    if (viewingKey.length != 43 || !_base64Url.hasMatch(viewingKey)) {
      throw ArgumentError.value(
        '<redacted>',
        'viewingKey',
        'must be a canonical 32-byte base64url key',
      );
    }
  }

  @override
  String toString() => 'EncryptedPrivateInvoice(<redacted>)';
}
