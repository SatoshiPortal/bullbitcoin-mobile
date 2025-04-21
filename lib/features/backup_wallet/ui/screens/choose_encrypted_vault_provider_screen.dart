import 'package:bb_mobile/core/recoverbull/data/constants/backup_providers.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/backup_provider.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/key_server.dart'
    show CurrentKeyServerFlow;
import 'package:bb_mobile/features/backup_wallet/presentation/bloc/backup_wallet_bloc.dart';
import 'package:bb_mobile/features/backup_wallet/ui/widgets/how_to_decide.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/router.dart' show AppRoute;
import 'package:bb_mobile/ui/components/bottom_sheet/x.dart';
import 'package:bb_mobile/ui/components/loading/progress_screen.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/components/vault/vault_locations.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart'
    show BlocBuilder, BlocListener, BlocProvider, ReadContext;
import 'package:gap/gap.dart';
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
    return BlocProvider(
      create: (context) => locator<BackupWalletBloc>(),
      child: const _Screen(),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();
  void _handleProviderTap(BuildContext context, BackupProviderEntity provider) {
    if (provider == backupProviders[0]) {
      context.read<BackupWalletBloc>().add(
            const OnGoogleDriveBackupSelected(),
          );
    } else if (provider == backupProviders[2]) {
      context.read<BackupWalletBloc>().add(
            const OnFileSystemBackupSelected(),
          );
    } else if (provider == backupProviders[3]) {
      debugPrint('Selected provider: ${provider.name}, not supported yet');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BackupWalletBloc, BackupWalletState>(
      listenWhen: (previous, current) =>
          current.status == BackupWalletStatus.success,
      listener: (context, state) {
        if (state.backupFile.isNotEmpty) {
          context.read<BackupWalletBloc>().add(const StartTransitioning());
          final bloc = context.read<BackupWalletBloc>();
          context.pushNamed(
            AppRoute.keyServerFlow.name,
            extra: (
              state.backupFile,
              CurrentKeyServerFlow.enter.toString(),
              false
            ),
          ).then((_) {
            bloc.add(const EndTransitioning());
          });
        }
      },
      child: BlocBuilder<BackupWalletBloc, BackupWalletState>(
        buildWhen: (previous, current) =>
            current.status != previous.status ||
            current.transitioning != previous.transitioning,
        builder: (context, state) {
          if ((state.status == BackupWalletStatus.loading) ||
              state.transitioning) {
            return Scaffold(
              backgroundColor: context.colour.onSecondary,
              body: ProgressScreen(
                title: state.vaultProvider is GoogleDrive
                    ? "You will need to sign-in to Google Drive"
                    : "Saving to your device.",
                description: state.vaultProvider is GoogleDrive
                    ? "Google will ask you to share personal information with this app."
                    : "",
                isLoading: true,
                extras: state.vaultProvider is GoogleDrive
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

          return _buildScaffold(context);
        },
      ),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          onBack: () => context.pop(),
          title: "Choose vault location",
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VaultLocations(
              onProviderSelected: (provider) =>
                  _handleProviderTap(context, provider),
            ),
            const Gap(16),
            _HowToDecideButton(),
          ],
        ),
      ),
    );
  }
}

class _HowToDecideButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showHowToDecideSheet(context),
      child: BBText(
        "How to decide?",
        style: context.font.headlineLarge?.copyWith(
          color: context.colour.primary,
        ),
      ),
    );
  }

  void _showHowToDecideSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const BlurredBottomSheet(
        child: HowToDecideSheetBackupOption(),
      ),
    );
  }
}
