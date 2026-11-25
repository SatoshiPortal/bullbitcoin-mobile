import 'dart:io';

import 'package:bb_mobile/features/settings/domain/usecases/watch_exchange_activation_offer_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/watch_quick_actions_visibility_usecase.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/swap_restore_cubit.dart';
import 'package:settings/settings.dart';
import 'package:swaps/swaps.dart';
import 'package:get_it/get_it.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_swap_rescue_wallets_usecase.dart';
import 'package:secrets/storage.dart' show SecretsInventory;

class SettingsLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<SwapRestoreCubit>(
      () =>
          SwapRestoreCubit(restoreSwapsUsecase: locator<RestoreSwapsUsecase>()),
    );
    locator.registerFactory<GetSwapRescueWalletsUsecase>(
      () => GetSwapRescueWalletsUsecase(
        inventory: locator<SecretsInventory>(),
        environment: locator<ActiveEnvironmentReader>(),
      ),
    );
    locator.registerLazySingleton<QuickActionsCubit>(
      () => createQuickActionsCubit(
        warning: log.warning,
        defaults: Platform.isIOS
            ? QuickActionsLayout.iosDefaults
            : QuickActionsLayout.defaults,
        exchangeVisible: WatchQuickActionsVisibilityUsecase(
          exchange: locator<Exchange>(),
          networkUnavailable: () => locator<Exchange>().networkUnavailable(),
          settings: locator<Preferences>(),
          isIOS: Platform.isIOS,
          platformChanges: locator<Settings>().watchSuperuser().map(
            (value) => ExchangeAvailability.platformAllowed(
              ExchangePlatform.current,
              isSuperuser: value,
            ),
          ),
        ).execute(),
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
  }) => WatchExchangeActivationOfferUsecase(
    exchange: locator<Exchange>(),
    platformAllowed: () => ExchangeAvailability.platformAllowed(
      ExchangePlatform.current,
      isSuperuser: locator<Settings>().isSuperuser,
    ),
    platformChanges: locator<Settings>().watchSuperuser().map(
      (value) => ExchangeAvailability.platformAllowed(
        ExchangePlatform.current,
        isSuperuser: value,
      ),
    ),
    onlyWhileOff: onlyWhileOff,
  ).execute();
}
