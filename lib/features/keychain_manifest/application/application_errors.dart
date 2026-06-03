class KeychainManifestApplicationException implements Exception {
  final String message;
  final Object? cause;

  const KeychainManifestApplicationException(this.message, {this.cause});

  @override
  String toString() => 'KeychainManifestApplicationException: $message';
}

class KeychainManifestReservationMismatchException
    extends KeychainManifestApplicationException {
  const KeychainManifestReservationMismatchException(super.message);
}

class KeychainManifestEntryConflictException
    extends KeychainManifestApplicationException {
  const KeychainManifestEntryConflictException(super.message, {super.cause});
}

class KeychainManifestDuplicateException
    extends KeychainManifestApplicationException {
  const KeychainManifestDuplicateException(super.message, {super.cause});
}
