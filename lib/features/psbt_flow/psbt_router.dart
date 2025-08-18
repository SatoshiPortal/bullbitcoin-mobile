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
      final psbt = state.extra as String?;
      return ShowPsbtScreen(psbt: psbt ?? '');
    },
  );
}
