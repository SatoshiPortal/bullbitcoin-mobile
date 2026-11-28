import 'package:bull_recoverbull/storage.dart';
import 'package:bull_ui/bull_ui.dart' show BullSnackBar;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:meta/meta.dart';
import 'package:preferences/preferences.dart' show Language;
import 'package:primitives/primitives.dart' show Network;
import 'package:provisioning/provisioning.dart';
import 'package:wallet_import/wallet_import.dart';

import 'domain/onboarding_operations.dart';
import 'domain/usecases/complete_physical_backup_verification_usecase.dart';
import 'domain/usecases/create_onboarding_wallet_usecase.dart';
import 'domain/usecases/recover_onboarding_wallet_usecase.dart';
import 'domain/usecases/scan_onboarding_wallet_usecase.dart';
import 'onboarding_navigation.dart';
import 'presentation/bloc/onboarding_bloc.dart';
import 'presentation/onboarding_failure_l10n.dart';
import 'ui/screens/advanced_options.dart';
import 'ui/screens/onboarding_physical_recovery.dart';
import 'ui/screens/onboarding_splash.dart';
import 'ui/screens/recover_options.dart';
import 'ui/widgets/splash_mark.dart';

final class OnboardingFeature {
  final ShellRoute route;
  final Widget Function() _loadingSplash;

  const OnboardingFeature._(this.route, this._loadingSplash);

  /// Mounts the routes without running wallet operations. A bloc is created
  /// for each visit to the onboarding shell. [records] selects the backup
  /// facts of a restored wallet's network.
  ///
  /// [logo] is shown on the create/recover screen and [loadingLogo] while a
  /// wallet is being created or restored. Both come from the host, so it can
  /// wrap them in the same affordance (the tap-to-unlock superuser gesture).
  /// [loadingLogo] defaults to the V3 [SplashMark] when omitted.
  static OnboardingFeature mount({
    required DefaultWalletProvisioning defaultWallets,
    required RecoverBullWalletBackups Function(Network) records,
    required ImportFeature walletImport,
    required void Function(BuildContext) onWalletReady,
    required Language Function(BuildContext) languageOf,
    required void Function(BuildContext, Language) changeLanguage,
    required Widget logo,
    Widget? loadingLogo,
    required ImageProvider background,
    required ImageProvider encryptedBackupIcon,
    required ImageProvider physicalBackupIcon,
  }) => mountOnboardingRoutes(
    createWallet: CreateOnboardingWalletUsecase(defaultWallets: defaultWallets)
        .execute,
    recoverWallet: RecoverOnboardingWalletUsecase(
      defaultWallets: defaultWallets,
      completePhysicalBackupVerificationUsecase:
          CompletePhysicalBackupVerificationUsecase(records: records),
    ).execute,
    walletImport: walletImport,
    onWalletReady: onWalletReady,
    languageOf: languageOf,
    changeLanguage: changeLanguage,
    logo: logo,
    loadingLogo: loadingLogo,
    background: background,
    encryptedBackupIcon: encryptedBackupIcon,
    physicalBackupIcon: physicalBackupIcon,
  );

  /// The startup view can be rendered before any onboarding route is active.
  Widget buildLoadingSplash(BuildContext context) => _loadingSplash();
}

/// Mounts the onboarding routes over already composed wallet operations.
/// Internal to the member: hosts use [OnboardingFeature.mount].
@internal
OnboardingFeature mountOnboardingRoutes({
  required CreateOnboardingWallet createWallet,
  required RecoverOnboardingWallet recoverWallet,
  required ImportFeature walletImport,
  required void Function(BuildContext) onWalletReady,
  required Language Function(BuildContext) languageOf,
  required void Function(BuildContext, Language) changeLanguage,
  required Widget logo,
  Widget? loadingLogo,
  required ImageProvider background,
  required ImageProvider encryptedBackupIcon,
  required ImageProvider physicalBackupIcon,
}) {
  final shellNavigatorKey = GlobalKey<NavigatorState>();
  Widget splash(bool loading) => OnboardingSplash(
    loading: loading,
    logo: loading ? (loadingLogo ?? const SplashMark()) : logo,
    background: background,
    advancedOptions: (_) =>
        AdvancedOptions(languageOf: languageOf, changeLanguage: changeLanguage),
  );

  return OnboardingFeature._(
    ShellRoute(
      builder: (context, state, child) => BlocProvider(
        create: (_) => OnboardingBloc(
          createWallet: createWallet,
          recoverWallet: recoverWallet,
          scanOnboardingWalletUsecase: ScanOnboardingWalletUsecase(
            walletImport,
          ),
        ),
        child: child,
      ),
      routes: [
        ShellRoute(
          navigatorKey: shellNavigatorKey,
          builder: (context, state, child) => MultiBlocListener(
            listeners: [
              BlocListener<OnboardingBloc, OnboardingState>(
                listenWhen: (previous, current) =>
                    !previous.isSuccess && current.isSuccess,
                listener: (context, _) => onWalletReady(context),
              ),
              BlocListener<OnboardingBloc, OnboardingState>(
                listenWhen: (previous, current) =>
                    previous.failure != current.failure &&
                    current.failure != null,
                listener: (context, state) {
                  if (state.failure case final failure?) {
                    BullSnackBar.show(
                      context,
                      message: failure.toTranslated(context),
                    );
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
              builder: (_, _) => splash(false),
              routes: [
                GoRoute(
                  name: OnboardingRoute.splash.name,
                  path: OnboardingRoute.splash.path,
                  builder: (_, _) => splash(false),
                ),
                GoRoute(
                  name: OnboardingRoute.recoverFromPhysical.name,
                  path: OnboardingRoute.recoverFromPhysical.path,
                  builder: (_, _) => const OnboardingPhysicalRecovery(),
                ),
                GoRoute(
                  name: OnboardingRoute.recoverOptions.name,
                  path: OnboardingRoute.recoverOptions.path,
                  builder: (_, _) => OnboardingRecoverOptions(
                    encryptedBackupIcon: encryptedBackupIcon,
                    physicalBackupIcon: physicalBackupIcon,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    () => splash(true),
  );
}
