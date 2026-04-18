import 'package:bb_mobile/core/notifications/notifications_service.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/share_logs_widget.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bb_mobile/features/app_unlock/ui/app_unlock_router.dart';
import 'package:bb_mobile/features/onboarding/ui/onboarding_router.dart';
import 'package:bb_mobile/features/onboarding/ui/screens/onboarding_splash.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';

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
              // show status of migration
            } else if (state is AppStartupSuccess) {
              // if (!state.hasDefaultWallets) return const OnboardingScreen();
              // if (state.isPinCodeSet) return const PinCodeUnlockScreen();
              // return const HomeScreen();
              return widget.app;
            } else if (state is AppStartupFailure) {
              return AppStartupFailureScreen(
                hasBackup: state.hasBackup,
                e: state.e,
              );
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
              // Gate pending swap-notification taps behind PIN unlock. The
              // onSuccess callback (passed via route extra) runs after the
              // user enters a valid PIN; if no tap is pending it falls
              // through to wallet home like the normal flow.
              AppRouter.router.go(
                AppUnlockRoute.appUnlock.path,
                extra: _postUnlockNavigator(),
              );
            } else if (state is AppStartupSuccess && !state.hasDefaultWallets) {
              AppRouter.router.go(OnboardingRoute.onboarding.path);
            } else if (state is AppStartupSuccess) {
              // Fully unlocked & onboarded — consume any notification tap
              // that landed before the router was ready.
              _consumePendingTapOrStay();
            }
          },
        ),
      ],
      child: child,
    );
  }

  /// Callback run by PinCodeUnlockScreen after a valid PIN entry. If a swap
  /// notification tap is pending, routes to the swap detail screen; otherwise
  /// replicates the default (wallet home) — once we pass a non-null
  /// `extra`, PinCodeUnlockScreen skips its own default.
  VoidCallback _postUnlockNavigator() {
    return () {
      final tap = locator<NotificationsService>().takePendingTap();
      if (tap != null) {
        AppRouter.router.goNamed(
          TransactionsRoute.swapTransactionDetails.name,
          pathParameters: {'swapId': tap.swapId},
          queryParameters: {'walletId': tap.walletId},
        );
      } else {
        AppRouter.router.goNamed('walletHome');
      }
    };
  }

  void _consumePendingTapOrStay() {
    final tap = locator<NotificationsService>().takePendingTap();
    if (tap == null) return;
    AppRouter.router.goNamed(
      TransactionsRoute.swapTransactionDetails.name,
      pathParameters: {'swapId': tap.swapId},
      queryParameters: {'walletId': tap.walletId},
    );
  }
}

class AppStartupFailureScreen extends StatelessWidget {
  const AppStartupFailureScreen({super.key, this.e, required this.hasBackup});

  final Object? e;
  final bool hasBackup;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: .center,
            mainAxisSize: .min,
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2.0),
                ),
                tileColor: context.appColors.error.withValues(alpha: 0.1),
                title: Row(
                  children: [
                    Icon(Icons.error_outline, color: context.appColors.error),
                    const Gap(8),
                    Text(
                      context.loc.appStartupErrorTitle,
                      style: context.font.headlineLarge?.copyWith(
                        color: context.appColors.error,
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    context.loc.appStartupErrorMessage,
                    style: context.font.bodyMedium?.copyWith(
                      color: context.appColors.secondary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Contact support at app.bullbitcoin.com/support',
                style: context.font.bodySmall?.copyWith(
                  color: context.appColors.secondary.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              BBButton.big(
                onPressed: () {
                  final url = Uri.parse(SettingsConstants.webSupportLink);
                  // ignore: deprecated_member_use
                  launchUrl(url, mode: LaunchMode.externalApplication);
                },
                label: context.loc.appStartupContactSupportButton,
                bgColor: context.appColors.primary,
                textColor: context.appColors.onPrimary,
              ),
              const SizedBox(height: 24),
              const ShareLogsWidget(),
            ],
          ),
        ),
      ),
    );
  }
}
