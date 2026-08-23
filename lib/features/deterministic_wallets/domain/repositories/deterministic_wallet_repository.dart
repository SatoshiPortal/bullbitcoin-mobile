import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/deterministic_wallets.dart';

abstract interface class DeterministicWalletRepository {
  Future<PreparedDeterministicWallet?> findMatchingWallet({
    required MnemonicSeed seed,
    required DeterministicWalletSpec spec,
  });

  Future<bool> seedExists(String fingerprint);
  Future<void> storeSeed(MnemonicSeed seed);

  Future<PreparedDeterministicWallet> createWallet({
    required MnemonicSeed seed,
    required DeterministicWalletSpec spec,
  });

  Future<void> deleteWallet(String walletId);
  Future<void> deleteSeed(String fingerprint);
}

final class DeterministicWalletMismatchException implements Exception {
  const DeterministicWalletMismatchException();
}
