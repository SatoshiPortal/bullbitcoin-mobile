import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/share_logs_widget.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/rescue_seeds_cubit.dart';
import 'package:bb_mobile/features/app_startup/ui/rescue_seed_bottom_sheet.dart';
import 'package:bb_mobile/features/app_unlock/ui/app_unlock_router.dart';
import 'package:bb_mobile/features/onboarding/ui/onboarding_router.dart';
import 'package:bb_mobile/features/onboarding/ui/screens/onboarding_splash.dart';
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

class AppStartupFailureScreen extends StatefulWidget {
  const AppStartupFailureScreen({super.key, this.e, required this.hasBackup});

  final Object? e;
  final bool hasBackup;

  @override
  State<AppStartupFailureScreen> createState() =>
      _AppStartupFailureScreenState();
}

class _AppStartupFailureScreenState extends State<AppStartupFailureScreen> {
  bool _showingSeeds = false;

  void _toggleRescueSeeds() {
    setState(() {
      _showingSeeds = !_showingSeeds;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showingSeeds) {
      return BlocProvider(
        create: (context) {
          final cubit = locator<RescueSeedsCubit>();
          cubit.loadSeeds();
          return cubit;
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _toggleRescueSeeds,
            ),
            title: Text(context.loc.rescueSeeds),
          ),
          body: const RescueSeedBottomSheet(),
        ),
      );
    }

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
              BBButton.big(
                onPressed: () {
                  final url = Uri.parse(SettingsConstants.telegramSupportLink);
                  // ignore: deprecated_member_use
                  launchUrl(url, mode: LaunchMode.externalApplication);
                },
                label: context.loc.appStartupContactSupportButton,
                bgColor: context.appColors.primary,
                textColor: context.appColors.onPrimary,
              ),
              const SizedBox(height: 16),
              BBButton.big(
                onPressed: _toggleRescueSeeds,
                label: context.loc.rescueSeeds,
                bgColor: context.appColors.secondary,
                textColor: context.appColors.onSecondary,
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
