import 'package:primitives/primitives.dart';

/// The seed and network selected before an asynchronous backup operation.
final class VaultContext {
  final Fingerprint fingerprint;
  final BitcoinNetwork network;

  const VaultContext({required this.fingerprint, required this.network});

  bool matches(VaultContext other) =>
      fingerprint == other.fingerprint && network == other.network;
}
