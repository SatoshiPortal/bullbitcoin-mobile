import 'package:secrets/src/domain/secret_info.dart';

/// What a listing found: the secrets it could describe, and how many entries it could not.
///
/// A corrupt entry is skipped so it cannot hide the others — but a list that is silently shorter than the keystore would let a user believe a wallet is gone. [unreadable] is that count, so the screen can say "and N entries could not be read" instead of nothing.
final class SecretListing<T> {
  final List<T> secrets;

  /// Entries under this package's prefix that parsed as nothing this package wrote, or whose words no longer pass bip39. Left in place.
  final int unreadable;

  const SecretListing({required this.secrets, required this.unreadable});

  SecretListing<R> map<R>(R Function(T) f) =>
      SecretListing(secrets: secrets.map(f).toList(), unreadable: unreadable);
}

/// The repository's half: descriptions plus the count.
typedef InfoListing = SecretListing<SecretInfo>;
