import 'package:secrets/secrets.dart';

/// Splits stored secrets into those a wallet still uses and those none does.
///
/// Every stored secret is shown. Secrets with the same words and different passphrases remain separate; the app receives handles and never reads words to deduplicate them.
class SeparateSecretsUsecase {
  const SeparateSecretsUsecase();

  ({List<Secret> existingWallets, List<Secret> oldWallets}) execute({
    required List<Secret> secrets,
    required Set<String> existingFingerprints,
  }) {
    final existing = <Secret>[];
    final old = <Secret>[];
    for (final secret in secrets) {
      (existingFingerprints.contains(secret.id.hex) ? existing : old).add(
        secret,
      );
    }
    return (existingWallets: existing, oldWallets: old);
  }
}
