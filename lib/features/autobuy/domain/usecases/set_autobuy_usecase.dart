import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/default_wallet.dart';
import 'package:exchange/exchange.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_default_wallets_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/autobuy/domain/autobuy_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class SetAutoBuyUsecase {
  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;
  final GetDefaultWalletsUsecase _getDefaultWalletsUsecase;
  final Preferences _settingsRepository;
  final Exchange _exchange;

  const SetAutoBuyUsecase(
    this._getExchangeUserSummaryUsecase,
    this._getDefaultWalletsUsecase,
    this._settingsRepository,
    this._exchange,
  );

  @useResult
  Future<Result<void, AutoBuyFailure>> execute({required bool enabled}) async {
    // The shared settings repository still throws, so this is its boundary.
    final ExchangeEnvironment environment;
    try {
      final settings = (await _settingsRepository.fetch()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      );
      if (!NetworkCapabilities.supports(
        BitcoinNetwork.fromName(settings.activeNetwork.name),
        NetworkCapability.exchange,
      )) {
        return const Err(AutoBuyUnsupportedNetworkFailure());
      }
      environment = settings.environment.requireHistoricalTestnet()
          ? ExchangeEnvironment.testnet
          : ExchangeEnvironment.mainnet;
    } on Error {
      rethrow;
    } catch (e, st) {
      // Type only, like every other boundary in this migration.
      log.severe(
        message: 'Failed to read settings before updating AutoBuy',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        AutoBuyUnexpectedFailure('settings fetch failed: ${e.runtimeType}'),
      );
    }

    if (enabled) {
      final DefaultWallets wallets;
      try {
        wallets = await _getDefaultWalletsUsecase.execute();
      } on Error {
        rethrow;
      } on ApiKeyException catch (e) {
        log.info('Exchange credential refused: ${e.runtimeType}');
        return Err(AutoBuyAccountUnavailableFailure('$e'));
      } on ExchangeCredentialUnavailableException catch (e) {
        log.info('Exchange credential refused: ${e.runtimeType}');
        return Err(AutoBuyAccountUnavailableFailure('$e'));
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
    } on GetExchangeUserSummaryCredentialException catch (e) {
      log.info('Exchange account credential refused: ${e.runtimeType}');
      return Err(AutoBuyAccountUnavailableFailure('$e'));
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

    final saved = await _exchange.saveUserPreference(
      environment,
      language: summary.language,
      currency: summary.currency,
      dcaEnabled: summary.dca.isActive,
      autoBuyEnabled: enabled.toString(),
      emailNotificationsEnabled: summary.emailNotificationsEnabled,
    );
    // The repository is the boundary and has already logged the raw reason.
    if (saved case Err(:final failure)) {
      return Err(AutoBuyPreferenceUpdateFailure(failure.logMessage));
    }

    return const Ok(null);
  }
}
