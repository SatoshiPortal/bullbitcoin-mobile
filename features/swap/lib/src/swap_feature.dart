import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:swaps/swaps.dart' show SwapRouting, SwapServerSettings;

import 'domain/usecases/get_swap_route_settings_usecase.dart';
import 'domain/usecases/get_swap_server_usecase.dart';
import 'domain/usecases/set_swap_exchange_fallback_usecase.dart';
import 'domain/usecases/set_swap_route_override_usecase.dart';
import 'domain/usecases/set_swap_server_usecase.dart';
import 'presentation/swap_settings_cubit.dart';
import 'swap_l10n.dart';
import 'ui/swap_settings_page.dart';

const _settingsRoute = 'swapSettings';

final class SwapFeature {
  final List<GoRoute> routes;

  const SwapFeature._(this.routes);

  factory SwapFeature.mount({
    required SwapRouting routing,
    required SwapServerSettings servers,
  }) => SwapFeature._(
    List.unmodifiable([
      GoRoute(
        name: _settingsRoute,
        path: '/swap-settings',
        builder: (_, _) => BlocProvider(
          create: (_) => SwapSettingsCubit(
            getSwapRouteSettingsUsecase: GetSwapRouteSettingsUsecase(routing),
            setSwapExchangeFallbackUsecase: SetSwapExchangeFallbackUsecase(
              routing,
            ),
            setSwapRouteOverrideUsecase: SetSwapRouteOverrideUsecase(routing),
            getSwapServerUsecase: GetSwapServerUsecase(servers),
            setSwapServerUsecase: SetSwapServerUsecase(servers),
          )..load(),
          child: const SwapSettingsPage(),
        ),
      ),
    ]),
  );
}

abstract final class SwapNavigation {
  static String settingsTitle(String localeName) =>
      swapCopy(localeName).swapSettingsTitle;

  static Future<void> openSettings(BuildContext context) =>
      context.pushNamed<void>(_settingsRoute);
}
