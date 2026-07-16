enum WalletMetadataBackupFormatExceptionType {
  malformed,
  unsupportedEnvelopeVersion,
  resourceLimit,
}

final class WalletMetadataBackupFormatException implements Exception {
  final WalletMetadataBackupFormatExceptionType type;
  final String message;
  final int? envelopeVersion;
  final Object? cause;

  const WalletMetadataBackupFormatException(
    this.type,
    this.message, {
    this.envelopeVersion,
    this.cause,
  });

  @override
  String toString() => 'WalletMetadataBackupFormatException: $message';
}
