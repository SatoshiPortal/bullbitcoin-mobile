import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/share_logs_widget.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bb_mobile/features/app_startup/ui/seed_recovery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';

class AppStartupWidget extends StatelessWidget {
  const AppStartupWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppStartupBloc, AppStartupState>(
      builder: (context, state) {
        if (state is AppStartupFailure) {
          return AppStartupFailureScreen(e: state.e);
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

class AppStartupFailureScreen extends StatelessWidget {
  const AppStartupFailureScreen({super.key, this.e});

  final Object? e;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (context) => Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
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
                        Icon(
                          Icons.error_outline,
                          color: context.appColors.error,
                        ),
                        const Gap(8),
                        Text(
                          'Rescue Build',
                          style: context.font.headlineLarge?.copyWith(
                            color: context.appColors.error,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'This is a special recovery build created to help users who forgot to backup their mnemonic and were affected by the flutter_secure_storage migration bug that may have failed.\n\nUse "Wallet Recovery" below to attempt recovery of your funds.',
                        style: context.font.bodyMedium?.copyWith(
                          color: context.appColors.secondary.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  BBButton.big(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SeedRecoveryScreen(),
                        ),
                      );
                    },
                    label: 'Wallet Recovery',
                    bgColor: context.appColors.error,
                    textColor: context.appColors.onError,
                  ),
                  const SizedBox(height: 16),
                  BBButton.big(
                    onPressed: () {
                      final url = Uri.parse(
                        SettingsConstants.telegramSupportLink,
                      );
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
        ),
      ),
    );
  }
}
