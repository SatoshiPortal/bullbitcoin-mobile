import 'package:bull_ui/bull_ui.dart' show BullSnackBar;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:preferences/preferences.dart' show Language;
import 'package:wallet_import/wallet_import.dart';

import 'domain/onboarding_operations.dart';
import 'domain/scan_onboarding_wallet_usecase.dart';
import 'onboarding_navigation.dart';
import 'presentation/bloc/onboarding_bloc.dart';
import 'presentation/onboarding_failure_l10n.dart';
import 'ui/screens/advanced_options.dart';
import 'ui/screens/onboarding_physical_recovery.dart';
import 'ui/screens/onboarding_splash.dart';
import 'ui/screens/recover_options.dart';

final class OnboardingFeature {
  final ShellRoute route;
  final Widget Function() _loadingSplash;

  const OnboardingFeature._(this.route, this._loadingSplash);

  /// Mounts the routes without running wallet operations. A bloc is created
  /// for each visit to the onboarding shell.
  static OnboardingFeature mount({
    required CreateOnboardingWallet createWallet,
    required RecoverOnboardingWallet recoverWallet,
    required ImportFeature walletImport,
    required void Function(BuildContext) onWalletReady,
    required Language Function(BuildContext) languageOf,
    required void Function(BuildContext, Language) changeLanguage,
    required Widget logo,
    required ImageProvider background,
    required ImageProvider encryptedBackupIcon,
    required ImageProvider physicalBackupIcon,
  }) {
    final shellNavigatorKey = GlobalKey<NavigatorState>();
    Widget splash(bool loading) => OnboardingSplash(
      loading: loading,
      logo: logo,
      background: background,
      advancedOptions: (_) => AdvancedOptions(
        languageOf: languageOf,
        changeLanguage: changeLanguage,
      ),
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

  /// The startup view can be rendered before any onboarding route is active.
  Widget buildLoadingSplash(BuildContext context) => _loadingSplash();
}
