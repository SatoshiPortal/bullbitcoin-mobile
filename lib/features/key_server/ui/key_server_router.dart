import 'package:bb_mobile/features/key_server/ui/key_server_flow.dart';
import 'package:go_router/go_router.dart';

enum KeyServerRoute {
  keyServerFlow('key-server-flow');

  final String path;

  const KeyServerRoute(this.path);
}

class KeyServerRouter {
  static final route = GoRoute(
    path: KeyServerRoute.keyServerFlow.path,
    builder: (context, state) {
      final (String? backupFile, String? flow, bool fromOnboarding) =
          state.extra! as (String?, String?, bool);
      return KeyServerFlow(
        backupFile: backupFile,
        currentFlow: flow,
        fromOnboarding: fromOnboarding,
      );
    },
  );
}
