import 'package:primitives/primitives.dart';

/// The default wallet selected before an asynchronous backup operation.
final class VaultContext {
  final Fingerprint fingerprint;
  final BitcoinNetwork network;
  final bool hasPassphrase;

  const VaultContext({
    required this.fingerprint,
    required this.network,
    this.hasPassphrase = false,
  });

  bool matches(VaultContext other) =>
      fingerprint == other.fingerprint && network == other.network;
}
