import '../../../domain/entities/drive_file_metadata.dart';
import '../../presentation/bloc.dart';
import '../../presentation/event.dart';
import '../../../presentation/recoverbull_failure_l10n.dart';
import '../../presentation/state.dart';
import 'package:flutter/material.dart';
import '../../../l10n/context_localizations.dart';
import '../../../ui/support.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
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

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          onBack: () => context.pop(),
          title: context.loc.recoverbullGoogleDriveScreenTitle,
        ),
      ),
      body: Column(
        children: [
          FadingLinearProgress(
            trigger: state.isLoading,
            backgroundColor: context.appColors.surface,
            foregroundColor: context.appColors.primary,
            height: 2.0,
          ),
          Expanded(
            child: failure != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(failure.toTranslated(context)),
                        const Gap(12),
                        BBButton.small(
                          label: context.loc.recoverbullRetry,
                          onPressed: () => context
                              .read<RecoverBullGoogleDriveBloc>()
                              .add(const OnFetchDriveVaults()),
                          bgColor: context.appColors.onSurface,
                          textColor: context.appColors.surface,
                        ),
                      ],
                    ),
                  )
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
    BlurredBottomSheet.show(
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
                  BBButton.small(
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
                  BBButton.small(
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
    BlurredBottomSheet.show(
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
              BBText(
                context.loc.recoverbullGoogleDriveDeleteVaultTitle,
                style: context.font.headlineMedium,
              ),
              const Gap(16),
              BBText(
                context.loc.recoverbullGoogleDriveDeleteConfirmation,
                style: context.font.bodyMedium,
                textAlign: .center,
              ),
              const Gap(24),
              Row(
                mainAxisAlignment: .spaceEvenly,
                children: [
                  BBButton.small(
                    label: context.loc.recoverbullGoogleDriveCancelButton,
                    onPressed: () => context.pop(),
                    bgColor: context.appColors.secondary,
                    textColor: context.appColors.onSecondary,
                  ),
                  BBButton.small(
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
