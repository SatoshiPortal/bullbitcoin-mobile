import 'package:primitives/primitives.dart';
import '../domain/exchange_access.dart';
import '../domain/exchange_availability.dart';
import '../domain/exchange_failure.dart';
import '../domain/usecases/get_exchange_account_usecase.dart';
import '../domain/usecases/save_exchange_preferences_usecase.dart';
import '../domain/usecases/resolve_exchange_access_usecase.dart';
import '../domain/usecases/enable_exchange_usecase.dart';
import '../domain/usecases/sign_out_exchange_usecase.dart';
import '../domain/usecases/watch_exchange_access_usecase.dart';
import '../domain/usecases/guard_exchange_trading_usecase.dart';
import 'exchange_account.dart';

export 'package:primitives/primitives.dart' show Err, Ok, Result;
export '../domain/exchange_failure.dart';
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
    required GetExchangeAccountUsecase getExchangeAccountUsecase,
    required SaveExchangePreferencesUsecase saveExchangePreferencesUsecase,
    required ResolveExchangeAccessUsecase resolveAccess,
    required this._enable,
    required this._signOut,
    required WatchExchangeAccessUsecase watchAccess,
    required this._tradingGuard,
  }) : _getAccount = getExchangeAccountUsecase,
       _savePreferences = saveExchangePreferencesUsecase,
       _resolve = resolveAccess,
       _watch = watchAccess;

  final GetExchangeAccountUsecase _getAccount;
  final SaveExchangePreferencesUsecase _savePreferences;
  final ResolveExchangeAccessUsecase _resolve;
  final EnableExchangeUsecase _enable;
  final SignOutExchangeUsecase _signOut;
  final WatchExchangeAccessUsecase _watch;
  final GuardExchangeTradingUsecase _tradingGuard;

  ExchangeAccess get currentAccess => _watch.current;
  Stream<ExchangeAccess> watchAccess() => _watch.execute();
  Future<Result<void, ExchangeFailure>> resolveAccess() => _resolve.execute();
  Future<Result<void, ExchangeFailure>> enable({bool? initialChoice}) =>
      _enable.execute(
        onlyIfUnset: initialChoice != null,
        choice: initialChoice ?? true,
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
