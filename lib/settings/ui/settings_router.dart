import 'package:bb_mobile/pin_code/ui/pin_code_setting_flow.dart';
import 'package:bb_mobile/settings/ui/screens/language_settings_screen.dart';
import 'package:go_router/go_router.dart';

enum SettingsSubroute {
  pinCode('pin-code'),
  language('language');

  final String path;

  const SettingsSubroute(this.path);
}

class SettingsRouter {
  static final routes = [
    GoRoute(
      name: SettingsSubroute.language.name,
      path: SettingsSubroute.language.path,
      builder: (context, state) => const LanguageSettingsScreen(),
    ),
    GoRoute(
      path: SettingsSubroute.pinCode.path,
      name: SettingsSubroute.pinCode.name,
      builder: (context, state) => const PinCodeSettingFlow(),
    ),
  ];
}
