import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/features/key_server/ui/key_server_flow.dart';
import 'package:go_router/go_router.dart';

enum KeyServerRoute {
  keyServerFlow('/key-server-flow');

  final String path;

  const KeyServerRoute(this.path);
}

class KeyServerRouter {
  static final route = GoRoute(
    name: KeyServerRoute.keyServerFlow.name,
    path: KeyServerRoute.keyServerFlow.path,
    builder: (context, state) {
      final (EncryptedVault? vault, String? flow, bool fromOnboarding) =
          state.extra! as (EncryptedVault?, String?, bool);
      return KeyServerFlow(
        vault: vault,
        currentFlow: flow,
        fromOnboarding: fromOnboarding,
      );
    },
  );
}
