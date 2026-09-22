import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/seed_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class GetDefaultSeedUsecase {
  final WalletRepository _walletRepository;
  final SeedRepository _seedRepository;

  GetDefaultSeedUsecase({
    required this._walletRepository,
    required this._seedRepository,
  });

  /// The seed behind the default Bitcoin wallet.
  ///
  /// Nothing here ever carries the seed, or a reason derived from it, into the
  /// failure: only the exception's runtime type. A `logMessage` is reachable
  /// from presentation, and this is key material (#1895).
  @useResult
  Future<Result<Seed, SeedFailure>> execute() async {
    final List<Wallet> wallets;
    switch (await _walletRepository.getWallets(
      onlyDefaults: true,
      onlyBitcoin: true,
    )) {
      case Ok(:final value):
        wallets = value;
      case Err(:final failure):
        log.warning('default seed: ${failure.logMessage}');
        return Err(SeedFetchFailure('default wallet: ${failure.runtimeType}'));
    }

    if (wallets.isEmpty) {
      return const Err(SeedFetchFailure('no default bitcoin wallet'));
    }

    // `SeedRepository.get` still throws and has nine callers across five
    // areas, so converting it is its own change. Until then this use case is
    // the boundary for it.
    try {
      return Ok(await _seedRepository.get(wallets.first.masterFingerprint));
    } catch (e, st) {
      log.severe(
        message: 'Failed to read the default seed',
        error: e.runtimeType,
        trace: st,
      );
      return Err(SeedFetchFailure('seed read: ${e.runtimeType}'));
    }
  }
}
