import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/features/psbt_flow/show_psbt/show_psbt_screen.dart';
import 'package:go_router/go_router.dart';

enum PsbtFlowRoutes {
  show('/show-psbt');

  final String path;
  const PsbtFlowRoutes(this.path);
}

class PsbtRouterConfig {
  static final route = GoRoute(
    name: PsbtFlowRoutes.show.name,
    path: PsbtFlowRoutes.show.path,
    builder: (context, state) {
      final extra = state.extra;
      final parameters =
          extra is ({String? psbt, SignerDeviceEntity? signerDevice})
          ? extra
          : null;
      return ShowPsbtScreen(
        psbt: parameters?.psbt ?? '',
        signerDevice: parameters?.signerDevice,
      );
    },
  );
}
