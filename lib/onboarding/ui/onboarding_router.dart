import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/onboarding/ui/screens/onboarding_recovery.dart';
import 'package:bb_mobile/onboarding/ui/screens/onboarding_recovery_success.dart';
import 'package:bb_mobile/onboarding/ui/screens/onboarding_splash.dart';
import 'package:bb_mobile/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum OnboardingSubroute {
  splash('splash'),
  recover('recover'),
  success('success');

  final String path;

  const OnboardingSubroute(this.path);
}

class OnboardingRouter {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> shellNavigatorKey =
      GlobalKey<NavigatorState>();

  static final route = ShellRoute(
    navigatorKey: rootNavigatorKey,
    builder: (context, state, child) => BlocProvider<OnboardingBloc>(
      create: (_) => locator<OnboardingBloc>(),
      child: child,
    ),
    routes: [
      ShellRoute(
        navigatorKey: OnboardingRouter.shellNavigatorKey,
        builder: (context, state, child) => MultiBlocListener(
          listeners: [
            BlocListener<OnboardingBloc, OnboardingState>(
              listenWhen: (previous, current) =>
                  previous.creating != current.creating &&
                  current.step == OnboardingStep.createSucess,
              listener: (context, state) {
                context.goNamed(AppRoute.home.name);
              },
            ),
            BlocListener<OnboardingBloc, OnboardingState>(
              listenWhen: (previous, current) => previous.step != current.step,
              listener: (context, state) {
                if (state.step == OnboardingStep.recoverySuccess) {
                  context.goNamed(OnboardingSubroute.success.name);
                }

                if (state.step == OnboardingStep.recoveryWords) {
                  context.pushNamed(OnboardingSubroute.recover.name);
                }
              },
            ),
          ],
          child: child,
        ),
        routes: [
          GoRoute(
            name: AppRoute.onboarding.name,
            path: AppRoute.onboarding.path,
            parentNavigatorKey: shellNavigatorKey,
            builder: (context, state) => const OnboardingSplash(),
            routes: [
              GoRoute(
                name: OnboardingSubroute.splash.name,
                path: OnboardingSubroute.splash.path,
                builder: (context, state) => const OnboardingSplash(),
              ),
              GoRoute(
                name: OnboardingSubroute.recover.name,
                path: OnboardingSubroute.recover.path,
                builder: (context, state) => const OnboardingRecovery(),
              ),
              GoRoute(
                name: OnboardingSubroute.success.name,
                path: OnboardingSubroute.success.path,
                builder: (context, state) => const OnboardingRecoverySuccess(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
