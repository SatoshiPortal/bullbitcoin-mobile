import 'package:bb_mobile/core/recoverbull/domain/entity/backup_info.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/features/onboarding/ui/screens/choose_encrypted_vault_provider_screen.dart';
import 'package:bb_mobile/features/onboarding/ui/screens/fetched_backup_info_screen.dart';
import 'package:bb_mobile/features/onboarding/ui/screens/onboarding_physical_recovery.dart';
import 'package:bb_mobile/features/onboarding/ui/screens/onboarding_recovery_success.dart';
import 'package:bb_mobile/features/onboarding/ui/screens/onboarding_splash.dart';
import 'package:bb_mobile/features/onboarding/ui/screens/recover_options.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum OnboardingSubroute {
  splash('splash'),
  recoverOptions('recover-options'),
  chooseRecoverProvider('choose-recover-provider'),
  backupInfo('recoverd-backup-info'),
  recoverFromEncrypted('recover-from-encrypted'),
  recoverFromPhysical('recover-from-physical'),
  recoverSuccess('recover-success');

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
                  (current.step == OnboardingStep.create) &&
                  current.onboardingStepStatus ==
                      const OnboardingStepStatus.success(),
              listener: (context, state) {
                context.goNamed(AppRoute.home.name);
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
                name: OnboardingSubroute.recoverFromPhysical.name,
                path: OnboardingSubroute.recoverFromPhysical.path,
                builder: (context, state) => const OnboardingPhysicalRecovery(),
              ),
              GoRoute(
                name: OnboardingSubroute.recoverFromEncrypted.name,
                path: OnboardingSubroute.recoverFromEncrypted.path,
                builder: (context, state) => const OnboardingPhysicalRecovery(),
              ),
              GoRoute(
                name: OnboardingSubroute.recoverOptions.name,
                path: OnboardingSubroute.recoverOptions.path,
                builder: (context, state) => const OnboardingRecoverOptions(),
              ),
              GoRoute(
                name: OnboardingSubroute.backupInfo.name,
                path: OnboardingSubroute.backupInfo.path,
                builder: (context, state) {
                  final backupInfo = state.extra! as BackupInfo;
                  return FetchedBackupInfoScreen(
                    encryptedInfo: backupInfo,
                  );
                },
              ),
              GoRoute(
                name: OnboardingSubroute.chooseRecoverProvider.name,
                path: OnboardingSubroute.chooseRecoverProvider.path,
                builder: (context, state) => const ChooseVaultProviderScreen(),
              ),
              GoRoute(
                name: OnboardingSubroute.recoverSuccess.name,
                path: OnboardingSubroute.recoverSuccess.path,
                builder: (context, state) => const OnboardingRecoverySuccess(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
