import 'package:bb_mobile/core/recoverbull/data/constants/backup_providers.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/backup_provider.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/bloc/test_wallet_backup_bloc.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/test_wallet_backup_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/ui/components/loading/progress_screen.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/vault/vault_locations.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart'
    show BlocBuilder, BlocListener, BlocProvider, ReadContext;
import 'package:go_router/go_router.dart';

class ChooseVaultProviderScreen extends StatefulWidget {
  const ChooseVaultProviderScreen({
    super.key,
  });

  @override
  State<ChooseVaultProviderScreen> createState() =>
      _ChooseVaultProviderScreenState();
}

class _ChooseVaultProviderScreenState extends State<ChooseVaultProviderScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider<TestWalletBackupBloc>(
      create: (_) => locator<TestWalletBackupBloc>(),
      child: const _Screen(),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  void _handleProviderTap(BuildContext context, BackupProviderEntity provider) {
    if (provider == backupProviders[0]) {
      context
          .read<TestWalletBackupBloc>()
          .add(const SelectGoogleDriveBackupTest());
    } else if (provider == backupProviders[2]) {
      context
          .read<TestWalletBackupBloc>()
          .add(const SelectFileSystemBackupTes());
    } else if (provider == backupProviders[3]) {
      debugPrint('Selected provider: ${provider.name}, not supported yet');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TestWalletBackupBloc, TestWalletBackupState>(
      listenWhen: (previous, current) =>
          current.isSuccess != previous.isSuccess ||
          current.error != previous.error,
      listener: (context, state) {
        if (state.isSuccess && !state.backupInfo.isCorrupted) {
          // Mark that we're starting navigation
          context.read<TestWalletBackupBloc>().add(const StartTransitioning());

          // Capture the bloc before the async gap
          final bloc = context.read<TestWalletBackupBloc>();

          context
              .pushNamed(
            TestWalletBackupSubroute.testBackupInfo.name,
            extra: state.backupInfo,
          )
              .then((_) {
            // When we return from the route, end the navigation state
            bloc.add(const EndTransitioning());
          });
        }
      },
      child: BlocBuilder<TestWalletBackupBloc, TestWalletBackupState>(
        buildWhen: (previous, current) =>
            current.isLoading != previous.isLoading ||
            current.error != previous.error ||
            current.isSuccess != previous.isSuccess ||
            current.transitioning != previous.transitioning,
        builder: (context, state) {
          // Show loading screen during loading OR navigation to avoid flickers
          if (state.isLoading || state.transitioning) {
            return Scaffold(
              backgroundColor: context.colour.onSecondary,
              body: ProgressScreen(
                title: (state.vaultProvider is GoogleDrive)
                    ? "You will need to sign-in to Google Drive"
                    : "Fetching from your device.",
                description: (state.vaultProvider is GoogleDrive)
                    ? "Google will ask you to share personal information with this app."
                    : "",
                isLoading: true,
                extras: (state.vaultProvider is GoogleDrive)
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
          title: 'Choose vault location',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: VaultLocations(
          description:
              'Test to make sure you can retrieve your encrypted vault.',
          onProviderSelected: (provider) =>
              _handleProviderTap(context, provider),
        ),
      ),
    );
  }
}
