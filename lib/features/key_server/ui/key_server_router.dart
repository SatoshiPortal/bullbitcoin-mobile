import 'package:bb_mobile/features/key_server/ui/key_server_flow.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
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
      final (String? backupFile, String? flow, OnboardingBloc? onboardingBloc) =
          state.extra! as (String?, String?, OnboardingBloc?);
      return KeyServerFlow(
        backupFile: backupFile,
        currentFlow: flow,
        onboardingBloc: onboardingBloc,
      );
    },
  );
}
