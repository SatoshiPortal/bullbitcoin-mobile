import 'package:bb_mobile/core/recoverbull/domain/entity/drive_file.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/features/onboarding/ui/screens/available_google_backups_screen.dart';
import 'package:bb_mobile/features/onboarding/ui/screens/choose_encrypted_vault_provider_screen.dart';
import 'package:bb_mobile/features/onboarding/ui/screens/fetched_backup_info_screen.dart';
import 'package:bb_mobile/features/onboarding/ui/screens/onboarding_physical_recovery.dart';
import 'package:bb_mobile/features/onboarding/ui/screens/onboarding_recovery_success.dart';
import 'package:bb_mobile/features/onboarding/ui/screens/onboarding_splash.dart';
import 'package:bb_mobile/features/onboarding/ui/screens/recover_options.dart';
import 'package:bb_mobile/features/onboarding/ui/screens/wallet_recovery_completion_screen.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum OnboardingRoute {
  onboarding('/onboarding'),
  splash('splash'),
  recoverOptions('recover-options'),
  chooseRecoverProvider('choose-recover-provider'),
  availableGoogleBackupsForRecovery('available-google-backups-for-recovery'),
  fetchedBackupInfo('fetched-backup-info'),
  recoverFromEncrypted('recover-from-encrypted'),
  recoverFromPhysical('recover-from-physical'),
  recoverSuccess('recover-success'),
  walletRecoveryCompletion('wallet-recovery-completion');

  final String path;

  const OnboardingRoute(this.path);
}

class OnboardingRouter {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> shellNavigatorKey =
      GlobalKey<NavigatorState>();

  static final route = ShellRoute(
    navigatorKey: rootNavigatorKey,
    builder:
        (context, state, child) => BlocProvider<OnboardingBloc>(
          create: (_) => locator<OnboardingBloc>(),
          child: child,
        ),
    routes: [
      ShellRoute(
        navigatorKey: OnboardingRouter.shellNavigatorKey,
        builder:
            (context, state, child) => MultiBlocListener(
              listeners: [
                BlocListener<OnboardingBloc, OnboardingState>(
                  listenWhen:
                      (previous, current) =>
                          !previous.isSuccess && current.isSuccess,
                  listener: (context, state) {
                    // Restart the wallet bloc to ensure it reflects the new wallets state
                    // with the recently created or recovered wallets before
                    // navigating.
                    context.read<WalletBloc>().add(const WalletStarted());
                    if (state.step == OnboardingStep.create) {
                      context.goNamed(WalletRoute.walletHome.name);
                    }
                  },
                ),
              ],
              child: child,
            ),
        routes: [
          GoRoute(
            name: OnboardingRoute.onboarding.name,
            path: OnboardingRoute.onboarding.path,
            parentNavigatorKey: shellNavigatorKey,
            builder: (context, state) => const OnboardingSplash(),
            routes: [
              GoRoute(
                name: OnboardingRoute.splash.name,
                path: OnboardingRoute.splash.path,
                builder: (context, state) => const OnboardingSplash(),
              ),
              GoRoute(
                name: OnboardingRoute.recoverFromPhysical.name,
                path: OnboardingRoute.recoverFromPhysical.path,
                builder: (context, state) => const OnboardingPhysicalRecovery(),
              ),
              GoRoute(
                name: OnboardingRoute.recoverFromEncrypted.name,
                path: OnboardingRoute.recoverFromEncrypted.path,
                builder: (context, state) => const OnboardingPhysicalRecovery(),
              ),
              GoRoute(
                name: OnboardingRoute.recoverOptions.name,
                path: OnboardingRoute.recoverOptions.path,
                builder: (context, state) => const OnboardingRecoverOptions(),
              ),
              GoRoute(
                name: OnboardingRoute.fetchedBackupInfo.name,
                path: OnboardingRoute.fetchedBackupInfo.path,
                builder: (context, state) {
                  final backupFileId = state.extra! as String;
                  return FetchedBackupInfoScreen(backupFileId: backupFileId);
                },
              ),
              GoRoute(
                name: OnboardingRoute.chooseRecoverProvider.name,
                path: OnboardingRoute.chooseRecoverProvider.path,
                builder: (context, state) => const ChooseVaultProviderScreen(),
              ),
              GoRoute(
                name: OnboardingRoute.availableGoogleBackupsForRecovery.name,
                path: OnboardingRoute.availableGoogleBackupsForRecovery.path,
                builder: (context, state) {
                  final backups = state.extra! as List<DriveFile>;
                  return AvailableGoogleBackupsScreen(backups: backups);
                },
              ),
              GoRoute(
                name: OnboardingRoute.recoverSuccess.name,
                path: OnboardingRoute.recoverSuccess.path,
                builder: (context, state) => const OnboardingRecoverySuccess(),
              ),
              GoRoute(
                name: OnboardingRoute.walletRecoveryCompletion.name,
                path: OnboardingRoute.walletRecoveryCompletion.path,
                builder: (context, state) {
                  final recoveredWallets =
                      state.extra! as (List<String>, List<Wallet>);
                  return WalletRecoveryCompletionScreen(
                    recoveredWallets: recoveredWallets,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
