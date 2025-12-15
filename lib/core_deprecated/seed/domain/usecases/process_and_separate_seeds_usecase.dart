import 'package:bb_mobile/core_deprecated/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core_deprecated/utils/logger.dart';

class ProcessAndSeparateSeedsUsecase {
  ProcessAndSeparateSeedsUsecase();

  ProcessedSeedsResult execute({
    required List<MnemonicSeed> seeds,
    required Set<String> existingFingerprints,
  }) {
    try {
      // Group seeds by mnemonic words (same mnemonic with different passphrases)
      final Map<String, MnemonicSeed> mnemonicMap = {};
      for (final seed in seeds) {
        final mnemonicKey = seed.mnemonicWords.join(' ');
        if (mnemonicMap.containsKey(mnemonicKey)) {
          // If same mnemonic exists, keep the one with passphrase if current doesn't have one
          final existing = mnemonicMap[mnemonicKey]!;
          if (existing.passphrase == null && seed.passphrase != null) {
            mnemonicMap[mnemonicKey] = seed;
          } else if (existing.passphrase != null && seed.passphrase == null) {
            // Keep existing one with passphrase
            continue;
          } else {
            // Both have or don't have passphrase, keep the first one encountered
            continue;
          }
        } else {
          mnemonicMap[mnemonicKey] = seed;
        }
      }

      // Separate seeds into existing wallets and old wallets
      final existingWallets = <MnemonicSeed>[];
      final oldWallets = <MnemonicSeed>[];

      for (final seed in mnemonicMap.values) {
        if (existingFingerprints.contains(seed.masterFingerprint)) {
          existingWallets.add(seed);
        } else {
          oldWallets.add(seed);
        }
      }

      return ProcessedSeedsResult(
        existingWallets: existingWallets,
        oldWallets: oldWallets,
      );
    } catch (e) {
      log.severe('Failed to process and separate seeds: $e');
      rethrow;
    }
  }
}

class ProcessedSeedsResult {
  final List<MnemonicSeed> existingWallets;
  final List<MnemonicSeed> oldWallets;

  ProcessedSeedsResult({
    required this.existingWallets,
    required this.oldWallets,
  });
}
