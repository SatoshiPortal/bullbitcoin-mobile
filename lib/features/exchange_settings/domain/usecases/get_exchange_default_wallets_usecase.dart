import 'package:bb_mobile/core/exchange/domain/entity/default_wallet.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_default_wallets_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/exchange_settings_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Wraps the shared exchange use-case, which still throws, so the cubit above
/// can switch on a `Result` instead of catching.
class GetExchangeDefaultWalletsUsecase {
  final GetDefaultWalletsUsecase _getDefaultWalletsUsecase;

  const GetExchangeDefaultWalletsUsecase({
    required this._getDefaultWalletsUsecase,
  });

  @useResult
  Future<Result<DefaultWallets, ExchangeSettingsFailure>> execute() async {
    try {
      return Ok(await _getDefaultWalletsUsecase.execute());
    } catch (e, st) {
      log.severe(message: 'getDefaultWallets failed', error: e, trace: st);
      return Err(
        ExchangeSettingsDefaultWalletsUnavailableFailure(
          'getDefaultWallets failed: ${e.runtimeType}',
        ),
      );
    }
  }
}
