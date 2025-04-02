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
    show BlocBuilder, BlocProvider, ReadContext;
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
          .add(const SelectGoogleDriveBackupTest());
    } else if (provider == backupProviders[3]) {
      debugPrint('Selected provider: ${provider.name}, not supported yet');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TestWalletBackupBloc, TestWalletBackupState>(
      builder: (context, state) {
        if (state.isLoading) {
          return Scaffold(
            backgroundColor: context.colour.onSecondary,
            body: ProgressScreen(
              title: "You will need to sign-in to Google Drive",
              description:
                  "Google will ask you to share personal information with this app.",
              isLoading: true,
              extras: [
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
              ],
            ),
          );
        }
        if (state.error.isNotEmpty) {
          return Scaffold(
            backgroundColor: context.colour.onSecondary,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error: ${state.error}',
                    style: TextStyle(color: context.colour.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }
        if (state.isSuccess && !state.backupInfo.isCorrupted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.pushNamed(
              TestWalletBackupSubroute.testBackupInfo.name,
              extra: state.backupInfo,
            );
          });
        }
        return _buildScaffold(context);
      },
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
