import 'package:bb_mobile/features/trezor/ui/screens/trezor_import_landing_screen.dart';
import 'package:go_router/go_router.dart';

enum TrezorRoute {
  importTrezor('/trezor-import');

  final String path;
  const TrezorRoute(this.path);
}

class TrezorRouter {
  static final routes = [
    GoRoute(
      name: TrezorRoute.importTrezor.name,
      path: TrezorRoute.importTrezor.path,
      builder: (context, state) => const TrezorImportLandingScreen(),
    ),
  ];
}
