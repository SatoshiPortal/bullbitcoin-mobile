import 'package:bb_mobile/core/recoverbull/domain/entity/drive_file_metadata.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recoverbull_google_drive/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull_google_drive/presentation/event.dart';
import 'package:bb_mobile/features/recoverbull_google_drive/presentation/recoverbull_google_drive_failure_l10n.dart';
import 'package:bb_mobile/features/recoverbull_google_drive/presentation/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullBottomSheet,
        BullButton,
        BullFadingLinearProgress,
        BullPage,
        BullText,
        BullTopBar,
        Gap;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DriveVaultsListPage extends StatelessWidget {
  const DriveVaultsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context
        .select<RecoverBullGoogleDriveBloc, RecoverBullGoogleDriveState>(
          (bloc) => bloc.state,
        );

    final failure = state.failure;
    final driveMetadata = state.driveMetadata;

    return BullPage(
      topBar: BullTopBar(
        onBack: () => context.pop(),
        title: context.loc.recoverbullGoogleDriveScreenTitle,
      ),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          BullFadingLinearProgress(
            trigger: state.isLoading,
            backgroundColor: context.appColors.surface,
            foregroundColor: context.appColors.primary,
            height: 2.0,
          ),
          Expanded(
            child: failure != null
                ? Center(child: Text(failure.toTranslated(context)))
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          if (!state.isLoading && driveMetadata.isEmpty)
                            Center(
                              child: Text(
                                context
                                    .loc
                                    .recoverbullGoogleDriveNoBackupsFound,
                              ),
                            ),

                          ...List.generate(driveMetadata.length, (index) {
                            final driveBackupMetadata = driveMetadata[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: _DriveFileMetadataItem(
                                driveFileMetadata: driveBackupMetadata,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DriveFileMetadataItem extends StatelessWidget {
  final DriveFileMetadata driveFileMetadata;

  const _DriveFileMetadataItem({required this.driveFileMetadata});

  void _showActionsBottomSheet(BuildContext context) {
    final bloc = context.read<RecoverBullGoogleDriveBloc>();
    BullBottomSheet.show(
      context: context,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.4,
        ),
        decoration: BoxDecoration(
          color: context.appColors.onSecondary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisSize: .min,
            children: [
              Row(
                mainAxisAlignment: .spaceEvenly,
                children: [
                  BullButton.small(
                    label: context.loc.recoverbullGoogleDriveExportButton,
                    onPressed: () {
                      context.pop();
                      bloc.add(
                        OnExportDriveFile(fileMetadata: driveFileMetadata),
                      );
                    },
                    bgColor: context.appColors.secondary,
                    textColor: context.appColors.onSecondary,
                  ),
                  BullButton.small(
                    label: context.loc.recoverbullGoogleDriveDeleteButton,
                    onPressed: () {
                      context.pop();
                      _showDeleteConfirmationBottomSheet(context);
                    },
                    bgColor: context.appColors.primary,
                    textColor: context.appColors.onPrimary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmationBottomSheet(BuildContext context) {
    final bloc = context.read<RecoverBullGoogleDriveBloc>();
    BullBottomSheet.show(
      context: context,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        decoration: BoxDecoration(
          color: context.appColors.onSecondary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisSize: .min,
            children: [
              BullText(
                context.loc.recoverbullGoogleDriveDeleteVaultTitle,
                style: context.font.headlineMedium,
              ),
              const Gap(16),
              BullText(
                context.loc.recoverbullGoogleDriveDeleteConfirmation,
                style: context.font.bodyMedium,
                textAlign: .center,
              ),
              const Gap(24),
              Row(
                mainAxisAlignment: .spaceEvenly,
                children: [
                  BullButton.small(
                    label: context.loc.recoverbullGoogleDriveCancelButton,
                    onPressed: () => context.pop(),
                    bgColor: context.appColors.secondary,
                    textColor: context.appColors.onSecondary,
                  ),
                  BullButton.small(
                    label: context.loc.recoverbullGoogleDriveDeleteButton,
                    onPressed: () {
                      context.pop();
                      bloc.add(
                        OnDeleteDriveFile(fileMetadata: driveFileMetadata),
                      );
                    },
                    bgColor: context.appColors.primary,
                    textColor: context.appColors.onPrimary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<RecoverBullGoogleDriveBloc>();
    final state = context
        .select<RecoverBullGoogleDriveBloc, RecoverBullGoogleDriveState>(
          (bloc) => bloc.state,
        );

    return ListTile(
      title: Text(
        '${DateFormat('MMM dd, yyyy • HH:mm').format(driveFileMetadata.createdTime.toLocal())} • ${driveFileMetadata.name}',
        maxLines: 2,
        overflow: .ellipsis,
      ),
      onTap: () =>
          bloc.add(OnSelectDriveFileMetadata(fileMetadata: driveFileMetadata)),
      onLongPress: () => _showActionsBottomSheet(context),
      enabled: !state.isLoading,
    );
  }
}
