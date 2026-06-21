/// Thrown by a [SecretStore] when `useAndForget` is asked for a key that is not
/// present. The repository/port boundary maps it to `SeedNotFoundFailure` —
/// which is DISTINCT from `KeychainLockedFailure` (a locked keychain is NOT a
/// missing seed).
class SecretNotFoundException implements Exception {
  const SecretNotFoundException(this.key);
  final String key;
  @override
  String toString() => 'SecretNotFoundException($key)';
}

/// Thrown by `SecretStore.store` when the key already exists (no silent
/// overwrite — oubliette parity). It is an `Exception` (not a `dart:core`
/// `Error`) so the repository can map a concurrent-import race to a benign
/// `DuplicateSeedFailure` rather than crash.
class SecretAlreadyExistsException implements Exception {
  const SecretAlreadyExistsException(this.key);
  final String key;
  @override
  String toString() => 'SecretAlreadyExistsException($key)';
}
