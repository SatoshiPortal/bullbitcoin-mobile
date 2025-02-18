import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bb_mobile/features/app_unlock/app_unlock_router.dart';
import 'package:bb_mobile/features/onboarding/presentation/onboarding_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum OnboardingRoute {
  onboarding('/onboarding');

  final String path;

  const OnboardingRoute(this.path);
}

class OnboardingRouter {
  static final route = GoRoute(
    name: OnboardingRoute.onboarding.name,
    path: OnboardingRoute.onboarding.path,
    redirect: (context, state) {
      // Check AppStartupState to skip onboarding if user has existing wallets
      final appStartupState = context.read<AppStartupBloc>().state;
      if (appStartupState is AppStartupSuccess &&
          appStartupState.hasExistingWallets) {
        // First thing to do is unlock the app if user has existing wallets
        return AppUnlockRoute.unlock.path;
      }

      return null;
    },
    builder: (context, state) => const OnboardingScreen(),
  );
}
