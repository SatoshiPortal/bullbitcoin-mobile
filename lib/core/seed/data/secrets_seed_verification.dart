import 'package:bb_mobile/core/seed/domain/seed_verification_port.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

final class SecretsSeedVerification implements SeedVerificationPort {
  final Secrets _secrets;

  const SecretsSeedVerification(this._secrets);

  @override
  Future<bool> matchesXpubs({
    required String fingerprint,
    required List<({String derivationPath, String xpub})> keys,
  }) async {
    if (keys.isEmpty) return false;
    final fetched = await _secrets.fetch(Fingerprint(fingerprint));
    final Secret secret;
    switch (fetched) {
      case Ok(:final value):
        secret = value;
      case Err(failure: SecretNotFoundFailure()):
        return false;
      case Err(:final failure):
        throw Exception('Secret verification: ${failure.runtimeType}');
    }
    for (final key in keys) {
      final account = await secret.derive.account(
        derivationPath: key.derivationPath,
        network: BitcoinNetwork.mainnet,
      );
      switch (account) {
        case Ok(:final value):
          if (value.fingerprint != secret.id ||
              value.xpub != Bip32Derivation.getBip32Xpub(key.xpub).toBase58()) {
            return false;
          }
        case Err(:final failure):
          throw Exception('Secret verification: ${failure.runtimeType}');
      }
    }
    return true;
  }
}
