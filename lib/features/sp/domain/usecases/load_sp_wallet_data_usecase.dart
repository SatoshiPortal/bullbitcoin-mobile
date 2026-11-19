import 'package:bb_mobile/features/sp/domain/entities/sp_wallet_data.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/usecases/ensure_sp_session_usecase.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart';
import 'package:meta/meta.dart';

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
      final SpWallet wallet;
      switch (await _ensureSpSessionUsecase.execute()) {
        case Err(:final failure):
          return Err(failure);
        case Ok(value: final w):
          if (w == null) return const Err(SpNotSetUp('SP session unavailable'));
          wallet = w;
      }
      _repository.notifyBalanceChanged(wallet.balance.totalUnifiedSat);
      final historyResult = await _repository.history();
      final coinsResult = await _repository.coins();
      final networkResult = _repository.network();
      final minBirthdayResult = _repository.minBirthdayHeight();
      switch ((historyResult, coinsResult, networkResult, minBirthdayResult)) {
        case (Err(failure: final f), _, _, _):
          return Err(f);
        case (_, Err(failure: final f), _, _):
          return Err(f);
        case (_, _, Err(failure: final f), _):
          return Err(f);
        case (_, _, _, Err(failure: final f)):
          return Err(f);
        case (
          Ok(value: final history),
          Ok(value: final coins),
          Ok(value: final network),
          Ok(value: final minBirthdayHeight),
        ):
          if (network == null || network != wallet.network) {
            return const Err(SpUnsupportedNetwork());
          }
          switch (await _ensureSpSessionUsecase.execute()) {
            case Err(:final failure):
              return Err(failure);
            case Ok(value: final current?)
                when current.network == wallet.network:
              break;
            case Ok():
              return const Err(SpUnsupportedNetwork());
          }
          return Ok(
            SpWalletData(
              wallet: wallet,
              history: [
                for (final payment in history)
                  payment.copyWith(network: network),
              ],
              coins: coins,
              network: network,
              chainTip: _repository.chainTip(),
              minBirthdayHeight: minBirthdayHeight,
            ),
          );
      }
    } catch (e) {
      return Err(SpUnexpected('SP wallet data load failed: $e'));
    }
  }
}
