import 'package:bb_mobile/features/pin_code/presentation/pin_code_setting_flow.dart';
import 'package:go_router/go_router.dart';

enum PinCodeRoute {
  pinCode('/pinCode');

  final String path;

  const PinCodeRoute(this.path);
}

class PinCodeRouter {
  static final route = GoRoute(
    name: PinCodeRoute.pinCode.name,
    path: PinCodeRoute.pinCode.path,
    builder: (context, state) => const PinCodeSettingFlow(),
  );
}
