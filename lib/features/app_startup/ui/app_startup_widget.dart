import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/widgets/share_logs_widget.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bb_mobile/features/app_unlock/ui/app_unlock_router.dart';
import 'package:bb_mobile/features/onboarding/ui/onboarding_router.dart';
import 'package:bb_mobile/features/onboarding/ui/screens/onboarding_splash.dart';
import 'package:bb_mobile/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
              return const AppStartupFailureScreen();
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
          listenWhen:
              (previous, current) =>
                  current is AppStartupSuccess && previous != current,
          listener: (context, state) {
            if (state is AppStartupSuccess && state.isPinCodeSet) {
              AppRouter.router.go(AppUnlockRoute.appUnlock.path);
            }

            if (state is AppStartupSuccess && !state.hasDefaultWallets) {
              AppRouter.router.go(OnboardingRoute.onboarding.path);
            }
          },
        ),
      ],
      child: child,
    );
  }
}

class AppStartupFailureScreen extends StatelessWidget {
  const AppStartupFailureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              BBText(
                'Something went wrong during startup.',
                textAlign: TextAlign.center,
                style: context.font.headlineMedium,
              ),

              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  final url = Uri.parse(SettingsConstants.telegramSupportLink);
                  // ignore: deprecated_member_use
                  launchUrl(url, mode: LaunchMode.externalApplication);
                },
                child: BBText(
                  'Contact Support',
                  style: context.font.headlineLarge,
                ),
              ),
              const SizedBox(height: 24),
              const ShareLogsWidget(migrationLogs: true, sessionLogs: true),
            ],
          ),
        ),
      ),
    );
  }
}
