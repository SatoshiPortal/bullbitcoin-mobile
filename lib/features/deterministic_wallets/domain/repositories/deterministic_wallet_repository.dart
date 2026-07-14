import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/deterministic_wallet_failure.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/deterministic_wallet_seed_material.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/deterministic_wallets.dart';
import 'package:meta/meta.dart';

abstract interface class DeterministicWalletRepository {
  @useResult
  Future<Result<PreparedDeterministicWallet?, DeterministicWalletFailure>>
  getMatchingWallet({
    required DeterministicWalletSeedMaterial seedMaterial,
    required DeterministicWalletSpec spec,
  });

  @useResult
  Future<Result<bool, DeterministicWalletFailure>> childSeedExists(
    String fingerprint,
  );

  @useResult
  Future<Result<void, DeterministicWalletFailure>> storeChildSeed(
    DeterministicWalletSeedMaterial seedMaterial,
  );

  @useResult
  Future<Result<PreparedDeterministicWallet, DeterministicWalletFailure>>
  createWallet({
    required DeterministicWalletSeedMaterial seedMaterial,
    required DeterministicWalletSpec spec,
  });

  @useResult
  Future<Result<void, DeterministicWalletFailure>> deleteWallet(
    String walletId,
  );

  @useResult
  Future<Result<void, DeterministicWalletFailure>> deleteChildSeed(
    String fingerprint,
  );
}
