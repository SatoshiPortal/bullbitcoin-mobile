import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/trezor/ui/screens/trezor_import_landing_screen.dart';
import 'package:bb_mobile/features/trezor/ui/screens/trezor_verify_address_screen.dart';
import 'package:go_router/go_router.dart';

enum TrezorRoute {
  importTrezor('/trezor-import'),
  trezorVerifyAddress('/trezor-verify-address');

  final String path;
  const TrezorRoute(this.path);
}

class TrezorVerifyAddressRouteParams {
  final String address;
  final String derivationPath;
  final ScriptType scriptType;

  const TrezorVerifyAddressRouteParams({
    required this.address,
    required this.derivationPath,
    this.scriptType = ScriptType.bip84,
  });
}

class TrezorRouter {
  static final routes = [
    GoRoute(
      name: TrezorRoute.importTrezor.name,
      path: TrezorRoute.importTrezor.path,
      builder: (context, state) => const TrezorImportLandingScreen(),
    ),
    GoRoute(
      name: TrezorRoute.trezorVerifyAddress.name,
      path: TrezorRoute.trezorVerifyAddress.path,
      builder: (context, state) {
        final extra = state.extra as TrezorVerifyAddressRouteParams?;
        return TrezorVerifyAddressScreen(params: extra);
      },
    ),
  ];
}
