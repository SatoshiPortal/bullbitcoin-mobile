import 'package:bb_mobile/core/exchange/domain/entity/default_wallet.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_default_wallets_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_user_preferences_usecase.dart';
import 'package:bb_mobile/features/autobuy/domain/autobuy_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class SetAutoBuyUsecase {
  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;
  final GetDefaultWalletsUsecase _getDefaultWalletsUsecase;
  final SaveUserPreferencesUsecase _saveUserPreferencesUsecase;

  const SetAutoBuyUsecase(
    this._getExchangeUserSummaryUsecase,
    this._getDefaultWalletsUsecase,
    this._saveUserPreferencesUsecase,
  );

  @useResult
  Future<Result<void, AutoBuyFailure>> execute({required bool enabled}) async {
    if (enabled) {
      final DefaultWallets wallets;
      try {
        wallets = await _getDefaultWalletsUsecase.execute();
      } on Error {
        rethrow;
      } catch (e, st) {
        log.severe(
          message: 'Failed to read the default wallets before enabling AutoBuy',
          error: e,
          trace: st,
        );
        return Err(AutoBuyUnexpectedFailure('$e'));
      }

      if (!wallets.hasAnyWallet) {
        return const Err(AutoBuyWalletRequiredFailure());
      }
    }

    final UserSummary summary;
    try {
      summary = await _getExchangeUserSummaryUsecase.execute();
    } on Error {
      rethrow;
    } on GetExchangeUserSummaryException catch (e, st) {
      log.severe(
        message: 'Failed to load account before updating AutoBuy',
        error: e,
        trace: st,
      );
      return Err(AutoBuyAccountUnavailableFailure('$e'));
    } catch (e, st) {
      log.severe(
        message: 'Failed to load account before updating AutoBuy',
        error: e,
        trace: st,
      );
      return Err(AutoBuyUnexpectedFailure('$e'));
    }

    if (enabled && summary.isFundingRestricted) {
      return const Err(AutoBuyFundingRestrictedFailure());
    }

    try {
      await _saveUserPreferencesUsecase.execute(
        language: summary.language,
        currency: summary.currency,
        dcaEnabled: summary.dca.isActive,
        autoBuyEnabled: enabled.toString(),
        emailNotificationsEnabled: summary.emailNotificationsEnabled,
      );
    } on Error {
      rethrow;
    } catch (e, st) {
      log.severe(
        message: 'Failed to update AutoBuy preference',
        error: e,
        trace: st,
      );
      return Err(AutoBuyPreferenceUpdateFailure('$e'));
    }

    return const Ok(null);
  }
}
