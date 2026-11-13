import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_session.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/initialize_exchange_access_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_trading_entry_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_account_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/save_exchange_preferences_usecase.dart';
import 'package:bb_mobile/features/exchange/public/exchange_account.dart';
import 'package:bb_mobile/features/exchange_access/public/exchange_access_facade.dart'
    show ExchangeAccessFacade;
import 'package:meta/meta.dart';

export 'package:bb_mobile/core/utils/result.dart' show Err, Ok, Result;
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
export '../domain/exchange_session.dart' show ExchangeSessionStatus;
export '../domain/usecases/get_exchange_trading_entry_usecase.dart'
    show ExchangeTradingEntry;

class ExchangeFacade {
  final GetExchangeAccountUsecase _getExchangeAccountUsecase;
  final SaveExchangePreferencesUsecase _saveExchangePreferencesUsecase;
  final void Function(bool)? _suspendSession;
  final GetExchangeTradingEntryUsecase? _tradingEntry;
  final ExchangeAccessFacade? _access;
  final ExchangeSession? _session;
  final InitializeExchangeAccessUsecase? _initializeAccess;
  final Future<ExchangeFailure?> Function()? _logout;

  const ExchangeFacade({
    required this._getExchangeAccountUsecase,
    required this._saveExchangePreferencesUsecase,
    this._tradingEntry,
    this._suspendSession,
    this._access,
    this._session,
    this._initializeAccess,
    this._logout,
  });

  ExchangeSessionStatus get session =>
      _session?.current ?? ExchangeSessionStatus.resolving;

  Stream<ExchangeSessionStatus> watchSession() =>
      _session?.watch() ?? const Stream.empty();

  Future<ExchangeSessionStatus> resolveSession({
    required bool isTestnet,
  }) async =>
      await _session?.resolve(isTestnet: isTestnet) ??
      ExchangeSessionStatus.unavailable;

  @useResult
  Future<Result<void, ExchangeFailure>> initializeAccess({
    required bool isTestnet,
  }) async {
    final usecase = _initializeAccess;
    if (usecase == null) return const Err(ExchangeUnexpectedFailure());
    final previousEnvironment = _access?.isTestnet;
    _suspendSession?.call(previousEnvironment != isTestnet);
    return usecase.execute(isTestnet: isTestnet);
  }

  @useResult
  Future<Result<ExchangeTradingEntry, ExchangeFailure>> tradingEntry({
    required bool isIOS,
  }) async {
    final usecase = _tradingEntry;
    if (usecase == null) return const Err(ExchangeUnexpectedFailure());
    return usecase.execute(isIOS: isIOS);
  }

  @useResult
  Future<Result<void, ExchangeFailure>> logout() async {
    final operation = _logout;
    if (operation == null) return const Err(ExchangeSessionClearFailure());
    final failure = await operation();
    return failure == null ? const Ok(null) : Err(failure);
  }

  @useResult
  Future<Result<ExchangeAccount, ExchangeFailure>> getAccount() async {
    if (_access != null && !_access.current.canUseAuthenticatedExchange) {
      return const Err(ExchangeNotAuthenticatedFailure());
    }
    final generation = _access?.generation;
    final result = await _getExchangeAccountUsecase.execute();
    if (_access != null && _access.generation != generation) {
      return const Err(ExchangeNotAuthenticatedFailure());
    }
    return result.map(
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
  }

  @useResult
  Future<Result<void, ExchangeFailure>> savePreferences({
    String? language,
    String? currency,
    bool? emailNotificationsEnabled,
  }) async {
    if (_access != null && !_access.current.canUseAuthenticatedExchange) {
      return const Err(ExchangeNotAuthenticatedFailure());
    }
    final generation = _access?.generation;
    final result = await _saveExchangePreferencesUsecase.execute(
      language: language,
      currency: currency,
      emailNotificationsEnabled: emailNotificationsEnabled,
    );
    if (_access != null && _access.generation != generation) {
      return const Err(ExchangeNotAuthenticatedFailure());
    }
    return result;
  }
}
