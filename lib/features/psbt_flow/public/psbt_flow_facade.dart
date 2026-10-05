import 'package:bb_mobile/features/psbt_flow/psbt_router.dart';

export 'package:bb_mobile/features/psbt_flow/show_animated_qr/show_animated_qr_widget.dart'
    show ShowAnimatedQrWidget;

class PsbtFlowFacade {
  const PsbtFlowFacade();

  String get showRouteName => PsbtFlowRoutes.show.name;
}
