import 'package:preferences/preferences.dart' show ExchangeWebPreferences;
import 'package:primitives/primitives.dart';

import 'package:exchange/exchange.dart';

import '../domain/usecases/resolve_exchange_access_usecase.dart';
import '../domain/usecases/enable_exchange_usecase.dart';
import '../domain/usecases/sign_out_exchange_usecase.dart';
import '../domain/usecases/watch_exchange_access_usecase.dart';
import '../domain/usecases/guard_exchange_trading_usecase.dart';

export 'package:primitives/primitives.dart' show Err, Ok, Result;

export '../exchange_locator.dart' show ExchangeLocator;
export '../presentation/exchange_failure_l10n.dart' show ExchangeFailureL10n;
export '../ui/exchange_router.dart'
    show ExchangeRoute, ExchangeRouter, ExchangeRouterConfig;
export '../ui/exchange_scope.dart'
    show ExchangeAccessBuilder, ExchangeScope, ExchangeSessionBuilder;

class ExchangeFacade {
  const ExchangeFacade({
    required this._loadWebPreferences,
    required this._saveAccountPreferences,
    required ResolveExchangeAccessUsecase resolveAccess,
    required this._enable,
    required this._signOut,
    required WatchExchangeAccessUsecase watchAccess,
    required this._tradingGuard,
  }) : _resolve = resolveAccess,
       _watch = watchAccess;

  final Future<Result<ExchangeWebPreferences, ExchangeFailure>> Function()
  _loadWebPreferences;
  final Future<Result<void, ExchangeFailure>> Function({
    String? language,
    String? currency,
    bool? emailNotificationsEnabled,
  })
  _saveAccountPreferences;
  final ResolveExchangeAccessUsecase _resolve;
  final EnableExchangeUsecase _enable;
  final SignOutExchangeUsecase _signOut;
  final WatchExchangeAccessUsecase _watch;
  final GuardExchangeTradingUsecase _tradingGuard;

  Future<bool> networkUnavailable() async {
    final result = await _loadWebPreferences();
    return switch (result) {
      Err(failure: ExchangeUnsupportedNetworkFailure()) => true,
      _ => false,
    };
  }

  ExchangeAccess get currentAccess => _watch.current;
  Stream<ExchangeAccess> watchAccess() => _watch.execute();
  Future<Result<void, ExchangeFailure>> resolveAccess() => _resolve.execute();
  Future<Result<void, ExchangeFailure>> enable({bool forSupport = false}) =>
      _enable.execute(forSupport: forSupport);
  Future<Result<void, ExchangeFailure>> logout() => _signOut.execute();
  Future<Result<ExchangeAvailability, ExchangeFailure>> guardTradingEntry() =>
      _tradingGuard.execute();

  Future<Result<void, ExchangeFailure>> savePreferences({
    String? language,
    String? currency,
    bool? emailNotificationsEnabled,
  }) => _saveAccountPreferences(
    language: language,
    currency: currency,
    emailNotificationsEnabled: emailNotificationsEnabled,
  );
}
