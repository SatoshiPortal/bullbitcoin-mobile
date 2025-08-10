import 'package:bb_mobile/core/recoverbull/domain/entity/key_server.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/key_server/ui/key_server_router.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/bloc/test_wallet_backup_bloc.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class FetchedBackupInfoScreen extends StatelessWidget {
  final String backupFileId;
  const FetchedBackupInfoScreen({super.key, required this.backupFileId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TestWalletBackupBloc>(
      create:
          (_) =>
              locator<TestWalletBackupBloc>()
                ..add(SelectCloudBackupTest(id: backupFileId)),
      child: Scaffold(
        appBar: AppBar(
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          flexibleSpace: TopBar(
            onBack: () => context.pop(),
            title: 'Recover Wallet',
          ),
        ),
        body: BlocBuilder<TestWalletBackupBloc, TestWalletBackupState>(
          builder: (context, state) {
            if (state.status == TestWalletBackupStatus.error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: BBText(
                    state.statusError,
                    style: context.font.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            // Show loading if backup is not yet loaded or is empty
            if (state.status == TestWalletBackupStatus.loading ||
                state.selectedBackup.backupFile.isEmpty) {
              return FadingLinearProgress(
                height: 3,
                trigger: true,
                backgroundColor: context.colour.primary,
                foregroundColor: context.colour.secondary,
              );
            }

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BBText(
                    'Your vault was successfully imported',
                    textAlign: TextAlign.left,
                    style: context.font.bodySmall,
                  ),
                  const Gap(16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: context.colour.surface),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _KeyValueRow(
                          label: 'Backup ID:',
                          value: state.selectedBackup.id,
                        ),
                        const Gap(8),
                        _KeyValueRow(
                          label: 'Created at:',
                          value: DateFormat(
                            "yyyy-MMM-dd, HH:mm:ss",
                          ).format(state.selectedBackup.createdAt.toLocal()),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Center(
                    child: BBButton.big(
                      label: 'Enter Backup key manually >>',
                      onPressed:
                          () => context.push(
                            KeyServerRoute.keyServerFlow.path,
                            extra: (
                              state.selectedBackup.backupFile,
                              CurrentKeyServerFlow.recoveryWithBackupKey.name,
                              false,
                            ),
                          ),
                      bgColor: Colors.transparent,
                      textStyle: context.font.bodySmall,
                      textColor: context.colour.inversePrimary,
                    ),
                  ),
                  const Gap(16),
                  BBButton.big(
                    label: 'Decrypt vault',
                    onPressed:
                        () => context.pushNamed(
                          KeyServerRoute.keyServerFlow.name,
                          extra: (
                            state.selectedBackup.backupFile,
                            CurrentKeyServerFlow.recovery.name,
                            false,
                          ),
                        ),
                    bgColor: context.colour.secondary,
                    textColor: context.colour.onSecondary,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  const _KeyValueRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(label, style: context.font.bodyMedium),
        const SizedBox(width: 8),
        Expanded(
          child: BBText(value, style: context.font.bodyLarge, maxLines: 3),
        ),
      ],
    );
  }
}
