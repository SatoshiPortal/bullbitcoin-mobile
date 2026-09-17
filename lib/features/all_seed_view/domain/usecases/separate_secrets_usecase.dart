import 'package:secrets/secrets.dart';

/// Splits stored secrets into those a wallet still uses and those none does.
///
/// Replaces the deduplication the old usecase performed on the raw words — same words, different passphrases collapsed to one entry. That is not done here: the words are not available, `mnemonicFingerprint` is 32 bits wide, and hiding an entry on a possibly colliding key is a way to make a secret disappear from the only screen that lists them. Every stored secret is shown. Grouping by `SecretInfo.mnemonicFingerprint`, for display only, can be layered on later without hiding anything.
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
