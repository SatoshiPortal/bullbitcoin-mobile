import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:meta/meta.dart';

/// Loads the data needed to open the sell amount-input screen: the exchange user
/// summary and the user's bitcoin unit.

class StartSellUsecase {
  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;
  final GetSettingsUsecase _getSettingsUsecase;

  StartSellUsecase({
    required this._getExchangeUserSummaryUsecase,
    required this._getSettingsUsecase,
  });

  @useResult
  Future<
    Result<({UserSummary userSummary, BitcoinUnit bitcoinUnit}), SellFailure>
  >
  execute() async {
    try {
      final userSummary = await _getExchangeUserSummaryUsecase.execute();
      final settings = await _getSettingsUsecase.execute();
      return Ok((userSummary: userSummary, bitcoinUnit: settings.bitcoinUnit));
    } catch (e, st) {
      log.severe(message: 'sell start failed', error: e, trace: st);
      return Err(SellUnexpectedFailure(e.toString()));
    }
  }
}
