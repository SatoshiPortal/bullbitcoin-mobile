import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_web_settings_usecase.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:preferences/preferences.dart' show Environment;
import 'package:primitives/primitives.dart';

import '../domain/exchange_access.dart';
import '../domain/exchange_availability.dart';

import 'package:exchange/exchange.dart';

import '../domain/usecases/get_exchange_account_usecase.dart';
import '../domain/usecases/save_exchange_preferences_usecase.dart';
import '../domain/usecases/resolve_exchange_access_usecase.dart';
import '../domain/usecases/enable_exchange_usecase.dart';
import '../domain/usecases/sign_out_exchange_usecase.dart';
import '../domain/usecases/watch_exchange_access_usecase.dart';
import '../domain/usecases/guard_exchange_trading_usecase.dart';
import 'exchange_account.dart';

export 'package:primitives/primitives.dart' show Err, Ok, Result;

export '../exchange_locator.dart' show ExchangeLocator;
export '../presentation/exchange_failure_l10n.dart' show ExchangeFailureL10n;
export '../ui/exchange_router.dart'
    show ExchangeRoute, ExchangeRouter, ExchangeRouterConfig;
export '../ui/exchange_scope.dart'
    show
        ExchangeAccessBuilder,
        ExchangeScope,
        ExchangeSessionBuilder,
        ExchangeSessionListener;
export '../ui/widgets/exchange_home_actions.dart' show ExchangeHomeAction;
export '../ui/widgets/exchange_account_sheets.dart' show ExchangeAccountSheets;
export '../ui/widgets/exchange_account_actions.dart'
    show ExchangeAccountActions;
export '../ui/widgets/exchange_amount_currency_dropdown.dart'
    show ExchangeAmountCurrencyDropdown;
export '../ui/widgets/exchange_amount_input_field.dart'
    show ExchangeAmountInputField;
export 'exchange_account.dart' show ExchangeAccount;

export '../domain/exchange_access.dart';
export '../domain/exchange_availability.dart';
export '../ui/exchange_trading_guard.dart' show ExchangeTradingGuard;

class ExchangeFacade {
  const ExchangeFacade({
    required GetExchangeWebSettingsUsecase getExchangeWebSettingsUsecase,
    required GetExchangeAccountUsecase getExchangeAccountUsecase,
    required SaveExchangePreferencesUsecase saveExchangePreferencesUsecase,
    required ResolveExchangeAccessUsecase resolveAccess,
    required this._enable,
    required this._signOut,
    required WatchExchangeAccessUsecase watchAccess,
    required this._tradingGuard,
  }) : _getWebSettings = getExchangeWebSettingsUsecase,
       _getAccount = getExchangeAccountUsecase,
       _savePreferences = saveExchangePreferencesUsecase,
       _resolve = resolveAccess,
       _watch = watchAccess;

  final GetExchangeWebSettingsUsecase _getWebSettings;
  final GetExchangeAccountUsecase _getAccount;
  final SaveExchangePreferencesUsecase _savePreferences;
  final ResolveExchangeAccessUsecase _resolve;
  final EnableExchangeUsecase _enable;
  final SignOutExchangeUsecase _signOut;
  final WatchExchangeAccessUsecase _watch;
  final GuardExchangeTradingUsecase _tradingGuard;

  Future<bool> networkUnavailable() async {
    final result = await _getWebSettings.execute();
    return switch (result) {
      Err(failure: ExchangeUnsupportedNetworkFailure()) => true,
      _ => false,
    };
  }

  Future<Result<ExchangeKycConfiguration, ExchangeFailure>> loadKyc() async =>
      (await _getWebSettings.execute()).map((settings) {
        final isTestnet = settings.environment == Environment.testnet;
        final username = settings.exchangeTestnetBasicAuthUsername;
        final password = settings.exchangeTestnetBasicAuthPassword;
        return (
          url: Uri.parse(
            isTestnet
                ? ApiServiceConstants.bbKycTestUrl
                : ApiServiceConstants.bbKycUrl,
          ),
          basicAuth: isTestnet && username != null && password != null
              ? (username: username, password: password)
              : null,
        );
      });

  ExchangeAccess get currentAccess => _watch.current;
  Stream<ExchangeAccess> watchAccess() => _watch.execute();
  Future<Result<void, ExchangeFailure>> resolveAccess() => _resolve.execute();
  Future<Result<void, ExchangeFailure>> enable({
    bool? initialChoice,
    bool forSupport = false,
  }) => _enable.execute(
    onlyIfUnset: initialChoice != null,
    choice: initialChoice ?? true,
    forSupport: forSupport,
  );
  Future<Result<void, ExchangeFailure>> logout() => _signOut.execute();
  Future<Result<ExchangeAvailability, ExchangeFailure>> guardTradingEntry() =>
      _tradingGuard.execute();

  Future<Result<ExchangeAccount, ExchangeFailure>> getAccount() async =>
      (await _getAccount.execute()).map(
        (account) => ExchangeAccount(
          userNumber: account.userNumber,
          firstName: account.profile.firstName,
          lastName: account.profile.lastName,
          email: account.email,
          language: account.language,
          currency: account.currency,
          emailNotificationsEnabled: account.emailNotificationsEnabled,
          isFullyVerifiedKycLevel: account.isFullyVerifiedKycLevel,
          isLightKycLevel: account.isLightKycLevel,
          isLimitedKycLevel: account.isLimitedKycLevel,
          isFundingRestricted: account.isFundingRestricted,
          hasConsentedScamWarning: account.hasConsentedScamWarning,
          payjoinReceiveEnabled: account.payjoinReceiveEnabled,
        ),
      );

  Future<Result<void, ExchangeFailure>> savePreferences({
    String? language,
    String? currency,
    bool? emailNotificationsEnabled,
  }) => _savePreferences.execute(
    language: language,
    currency: currency,
    emailNotificationsEnabled: emailNotificationsEnabled,
  );
}
