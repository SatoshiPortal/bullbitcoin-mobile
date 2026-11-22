import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

import 'ui/pin_code_setting_flow.dart';
import 'ui/pin_code_unlock_screen.dart';

/// Optional completion override for the startup unlock route.
final class AppUnlockRouteData {
  final VoidCallback? onSuccess;

  const AppUnlockRouteData({this.onSuccess});

  static const name = 'appUnlock';
  static const path = '/app-unlock';

  void go(GoRouter router) =>
      router.goNamed(name, extra: onSuccess == null ? null : this);
}

final class PinSettingsRouteData {
  const PinSettingsRouteData();

  static const name = 'pinCode';
  static const path = 'pin-code';

  Future<void> push(BuildContext context) => context.pushNamed<void>(name);
}

abstract final class AccessRoutes {
  static GoRoute unlock({required void Function(BuildContext) onUnlocked}) =>
      GoRoute(
        name: AppUnlockRouteData.name,
        path: AppUnlockRouteData.path,
        builder: (context, state) {
          final onSuccess = switch (state.extra) {
            AppUnlockRouteData(:final onSuccess) => onSuccess,
            _ => null,
          };
          return PinCodeUnlockScreen(
            onSuccess: onSuccess ?? () => onUnlocked(context),
          );
        },
      );

  static GoRoute pinSettings({
    required Future<void> Function(BuildContext) onBackUp,
  }) => GoRoute(
    name: PinSettingsRouteData.name,
    path: PinSettingsRouteData.path,
    builder: (context, state) => PinCodeSettingFlow(onBackUp: onBackUp),
  );
}
