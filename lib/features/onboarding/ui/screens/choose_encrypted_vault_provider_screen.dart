import 'package:bb_mobile/core/recoverbull/domain/entity/backup_provider.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/backup_provider_type.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/widgets/loading/progress_screen.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/selectors/backup_provider_selector.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/features/onboarding/ui/onboarding_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart'
    show BlocBuilder, BlocListener, BlocProvider, ReadContext;
import 'package:go_router/go_router.dart';

class ChooseVaultProviderScreen extends StatefulWidget {
  const ChooseVaultProviderScreen({super.key});

  @override
  State<ChooseVaultProviderScreen> createState() =>
      _ChooseVaultProviderScreenState();
}

class _ChooseVaultProviderScreenState extends State<ChooseVaultProviderScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider<OnboardingBloc>(
      create: (_) => locator<OnboardingBloc>(),
      child: const _Screen(),
    );
  }
}

class _Screen extends StatefulWidget {
  const _Screen();

  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> {
  void onProviderSelected(BuildContext context, BackupProviderType provider) {
    switch (provider) {
      case BackupProviderType.googleDrive:
        context.read<OnboardingBloc>().add(const SelectGoogleDriveRecovery());
      case BackupProviderType.custom:
        context.read<OnboardingBloc>().add(const SelectFileSystemRecovery());
      case BackupProviderType.iCloud:
        log.info('iCloud, not supported yet');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OnboardingBloc, OnboardingState>(
      listenWhen:
          (previous, current) =>
              current.onboardingStepStatus != previous.onboardingStepStatus,
      listener: (context, state) {
        if (state.onboardingStepStatus == OnboardingStepStatus.success &&
            !state.backupInfo.isCorrupted) {
          // Mark that we're starting navigation
          context.read<OnboardingBloc>().add(const StartTransitioning());

          // Capture the bloc before the async gap
          final bloc = context.read<OnboardingBloc>();

          context
              .pushNamed(
                OnboardingRoute.retrievedBackupInfo.name,
                extra: state.backupInfo,
              )
              .then((_) {
                // When we return from the route, end the navigation state
                if (mounted) {
                  bloc.add(const EndTransitioning());
                }
              });
        }
      },
      child: BlocBuilder<OnboardingBloc, OnboardingState>(
        buildWhen:
            (previous, current) =>
                current.onboardingStepStatus != previous.onboardingStepStatus ||
                current.transitioning != previous.transitioning,
        builder: (context, state) {
          // Show loading screen during loading OR navigation to avoid flickers
          if (state.onboardingStepStatus == OnboardingStepStatus.loading ||
              state.transitioning) {
            return Scaffold(
              backgroundColor: context.colour.onSecondary,
              body: ProgressScreen(
                title:
                    (state.vaultProvider is GoogleDrive)
                        ? "You will need to sign-in to Google Drive"
                        : "Fetching from your device.",
                description:
                    (state.vaultProvider is GoogleDrive)
                        ? "Google will ask you to share personal information with this app."
                        : "",
                isLoading: true,
                extras:
                    (state.vaultProvider is GoogleDrive)
                        ? [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: "This information ",
                                  style: context.font.headlineMedium,
                                ),
                                TextSpan(
                                  text: "will not ",
                                  style: context.font.headlineLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text: "leave your phone and is ",
                                  style: context.font.headlineMedium,
                                ),
                                TextSpan(
                                  text: "never ",
                                  style: context.font.headlineLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text: "shared with Bull Bitcoin.",
                                  style: context.font.headlineMedium,
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ]
                        : [],
              ),
            );
          }

          return buildScaffold(context);
        },
      ),
    );
  }

  Widget buildScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          onBack: () => context.pop(),
          title: 'Recover Wallet',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: BackupProviderSelector(
          onProviderSelected:
              (provider) => onProviderSelected(context, provider),
        ),
      ),
    );
  }
}
