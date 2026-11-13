import 'dart:io';

import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';

class WatchSettingsExchangeAccessUsecase {
  const WatchSettingsExchangeAccessUsecase(this._exchange);
  final ExchangeFacade _exchange;

  ExchangeAccess get current => _exchange.currentAccess;
  Stream<ExchangeAccess> execute() => _exchange.watchAccess();
}

class SetSettingsExchangeAccessUsecase {
  SetSettingsExchangeAccessUsecase(
    this._exchange,
    this._settings, {
    bool Function()? isIOS,
  }) : _isIOS = isIOS ?? (() => Platform.isIOS);
  final ExchangeFacade _exchange;
  final SettingsRepository _settings;
  final bool Function() _isIOS;

  Future<Result<void, SettingsFailure>> execute(bool enabled) async {
    if (enabled && _isIOS()) {
      try {
        if ((await _settings.fetch()).isSuperuser != true) {
          return const Err(SettingsExchangeSyncFailure());
        }
      } on Exception {
        return const Err(SettingsExchangeSyncFailure());
      }
    }
    final result = enabled
        ? await _exchange.enable()
        : await _exchange.logout();
    return result.mapErr((_) => const SettingsExchangeSyncFailure());
  }

  Future<Result<void, SettingsFailure>> retry() async {
    final result = await _exchange.resolveAccess();
    return result.mapErr((_) => const SettingsExchangeSyncFailure());
  }
}
