class KeychainManifestInvalidEntryException implements Exception {
  final String message;

  const KeychainManifestInvalidEntryException(this.message);

  @override
  String toString() => 'KeychainManifestInvalidEntryException: $message';
}
