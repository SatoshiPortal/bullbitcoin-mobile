import 'package:bb_mobile/core_deprecated/entities/signer_device_entity.dart';
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
      final extra =
          state.extra! as ({String? psbt, SignerDeviceEntity? signerDevice});
      return ShowPsbtScreen(
        psbt: extra.psbt ?? '',
        signerDevice: extra.signerDevice,
      );
    },
  );
}
