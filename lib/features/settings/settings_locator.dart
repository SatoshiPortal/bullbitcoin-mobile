import 'dart:io';

import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:exchange/exchange.dart';
import 'package:settings/settings.dart';
import 'package:get_it/get_it.dart';

class SettingsLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton<QuickActionsCubit>(
      () => createQuickActionsCubit(
        warning: log.warning,
        defaults: Platform.isIOS
            ? QuickActionsLayout.iosDefaults
            : QuickActionsLayout.defaults,
        exchangeVisible: locator<Exchange>().watchTradingVisibility(
          platform: ExchangePlatform.current,
          superuserChanges: locator<Settings>().watchSuperuser(),
        ),
        exchangeEntry: _exchangeActivationOffer(locator, onlyWhileOff: false),
      ),
      dispose: (cubit) => cubit.close(),
    );
    locator.registerLazySingleton<ExchangePromptCubit>(
      () => createExchangePromptCubit(
        warning: log.warning,
        offered: _exchangeActivationOffer(locator, onlyWhileOff: true),
      ),
      dispose: (cubit) => cubit.close(),
    );
  }

  static Stream<bool> _exchangeActivationOffer(
    GetIt locator, {
    required bool onlyWhileOff,
  }) => locator<Exchange>().watchActivationOffer(
    platform: ExchangePlatform.current,
    currentSuperuser: () => locator<Settings>().isSuperuser,
    superuserChanges: locator<Settings>().watchSuperuser(),
    onlyWhileOff: onlyWhileOff,
  );
}
