import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/usecases/ensure_sp_session_usecase.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart';
import 'package:meta/meta.dart';

void _spDiag(String message) {
  // ignore: avoid_print
  print(message);
}

/// Reads the current wallet snapshot + payment history + backend info in one
/// call (used by the cubit on load and after coin-change notifications).
class SpWalletData {
  final SpWallet wallet;
  final List<SpPayment> history;
  final List<SpCoin> coins;
  final SpNetwork? network;
  final bool backendOnline;
  final int? chainTip;
  final int minBirthdayHeight;

  const SpWalletData({
    required this.wallet,
    required this.history,
    required this.coins,
    required this.network,
    required this.backendOnline,
    this.chainTip,
    this.minBirthdayHeight = 0,
  });
}

class LoadSpWalletDataUsecase {
  final SpAccountRepository _repository;
  final EnsureSpSessionUsecase _ensureSpSessionUsecase;

  LoadSpWalletDataUsecase({
    required this._repository,
    required this._ensureSpSessionUsecase,
  });

  @useResult
  Future<Result<SpWalletData, SpFailure>> execute() async {
    try {
      // Establish (or reuse) the live session, reconstructing it from the
      // persisted config if it was recycled out from under us. A null result
      // means the wallet is gone (revoked / not set up).
      final wallet = await _ensureSpSessionUsecase.execute();
      if (wallet == null) {
        _spDiag('SPDIAG dart load_data wallet_null');
        return const Err(SpNotSetUp('SP session unavailable'));
      }
      _spDiag(
        'SPDIAG dart load_data wallet_total=${wallet.balance.totalUnifiedSat} '
        'confirmed=${wallet.balance.confirmedSat}',
      );
      _repository.notifyBalanceChanged(wallet.balance.totalUnifiedSat);
      final historyResult = await _repository.history();
      final coinsResult = await _repository.coins();
      _spDiag(
        'SPDIAG dart load_data history=${switch (historyResult) {
          Ok(value: final h) => h.length,
          Err() => 'err',
        }} '
        'coins=${switch (coinsResult) {
          Ok(value: final c) => c.length,
          Err() => 'err',
        }}',
      );
      return switch ((historyResult, coinsResult)) {
        (Err(failure: final f), _) => Err(f),
        (_, Err(failure: final f)) => Err(f),
        (Ok(value: final history), Ok(value: final coins)) => Ok(
          SpWalletData(
            wallet: wallet,
            history: history,
            coins: coins,
            network: _repository.network(),
            backendOnline: _repository.backendOnline(),
            chainTip: _repository.chainTip(),
            minBirthdayHeight: _repository.minBirthdayHeight(),
          ),
        ),
      };
    } catch (e) {
      return Err(SpUnexpected('SP wallet data load failed: $e'));
    }
  }
}
