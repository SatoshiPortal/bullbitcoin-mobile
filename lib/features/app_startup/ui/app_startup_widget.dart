import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bb_mobile/features/onboarding/ui/screens/onboarding_splash.dart';
import 'package:bb_mobile/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AppStartupWidget extends StatefulWidget {
  const AppStartupWidget({super.key, required this.app});

  final Widget app;

  @override
  State<AppStartupWidget> createState() => _AppStartupWidgetState();
}

class _AppStartupWidgetState extends State<AppStartupWidget> {
  @override
  Widget build(BuildContext context) {
    return AppStartupListener(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: BlocBuilder<AppStartupBloc, AppStartupState>(
          builder: (context, state) {
            if (state is AppStartupInitial) {
              return const OnboardingSplash(loading: true);
            } else if (state is AppStartupLoadingInProgress) {
              return const OnboardingSplash(loading: true);
            } else if (state is AppStartupSuccess) {
              // if (!state.hasDefaultWallets) return const OnboardingScreen();
              // if (state.isPinCodeSet) return const PinCodeUnlockScreen();
              // return const HomeScreen();
              return widget.app;
            } else if (state is AppStartupFailure) {
              // TODO: return a failure page
            }

            // TODO: remove this when all states are handled and return the
            //  appropriate widget
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class AppStartupListener extends StatelessWidget {
  const AppStartupListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AppStartupBloc, AppStartupState>(
          listenWhen: (previous, current) =>
              current is AppStartupSuccess && previous != current,
          listener: (context, state) {
            if (state is AppStartupSuccess && state.isPinCodeSet) {
              AppRouter.router.go(AppRoute.appUnlock.path);
            }

            if (state is AppStartupSuccess && !state.hasDefaultWallets) {
              AppRouter.router.go(AppRoute.onboarding.path);
            }
          },
        ),
      ],
      child: child,
    );
  }
}
