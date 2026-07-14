import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/deterministic_wallet_failure.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/deterministic_wallet_seed_material.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/deterministic_wallets.dart';

abstract interface class DeterministicWalletRepository {
  Future<Result<PreparedDeterministicWallet?, DeterministicWalletFailure>>
  getMatchingWallet({
    required DeterministicWalletSeedMaterial seedMaterial,
    required DeterministicWalletSpec spec,
  });

  Future<Result<bool, DeterministicWalletFailure>> childSeedExists(
    String fingerprint,
  );

  Future<Result<void, DeterministicWalletFailure>> storeChildSeed(
    DeterministicWalletSeedMaterial seedMaterial,
  );

  Future<Result<PreparedDeterministicWallet, DeterministicWalletFailure>>
  createWallet({
    required DeterministicWalletSeedMaterial seedMaterial,
    required DeterministicWalletSpec spec,
  });

  Future<Result<void, DeterministicWalletFailure>> deleteWallet(
    String walletId,
  );

  Future<Result<void, DeterministicWalletFailure>> deleteChildSeed(
    String fingerprint,
  );
}
