import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Fingerprint;
import 'package:secrets/src/domain/failures.dart';
import 'package:secrets/src/domain/secret_info.dart';

/// Internal descriptions and individual unreadable entries. Each failure keeps its fingerprint when the storage key is valid.
final class SecretListing<T> {
  final List<T> secrets;

  /// Entries under this package's prefix that parsed as nothing this package wrote, or whose words no longer pass bip39. Left in place.
  final List<({Fingerprint? id, SecretFailure failure})> unreadable;

  @internal
  const SecretListing({required this.secrets, required this.unreadable});
}

/// The repository's projection before public handles are built.
typedef InfoListing = SecretListing<SecretInfo>;
