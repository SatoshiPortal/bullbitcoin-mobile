import 'package:bb_mobile/core/recoverbull/domain/entity/drive_file_metadata.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/recoverbull_google_drive/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull_google_drive/presentation/event.dart';
import 'package:bb_mobile/features/recoverbull_google_drive/presentation/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
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

    final error = state.error;
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
            backgroundColor: context.colour.surface,
            foregroundColor: context.colour.primary,
            height: 2.0,
          ),
          Expanded(
            child:
                error != null
                    ? Center(child: Text(error.message))
                    : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            if (!state.isLoading && driveMetadata.isEmpty)
                              Center(child: Text(context.loc.recoverbullGoogleDriveNoBackupsFound)),

                            ...List.generate(driveMetadata.length, (index) {
                              final driveBackupMetadata = driveMetadata[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
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
          color: context.colour.onPrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  BBButton.small(
                    label: context.loc.recoverbullGoogleDriveExportButton,
                    onPressed: () {
                      context.pop();
                      bloc.add(
                        OnExportDriveFile(fileMetadata: driveFileMetadata),
                      );
                    },
                    bgColor: context.colour.secondary,
                    textColor: context.colour.onSecondary,
                  ),
                  BBButton.small(
                    label: context.loc.recoverbullGoogleDriveDeleteButton,
                    onPressed: () {
                      context.pop();
                      _showDeleteConfirmationBottomSheet(context);
                    },
                    bgColor: context.colour.primary,
                    textColor: context.colour.onPrimary,
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
          color: context.colour.onPrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BBText(context.loc.recoverbullGoogleDriveDeleteVaultTitle, style: context.font.headlineMedium),
              const Gap(16),
              BBText(
                context.loc.recoverbullGoogleDriveDeleteConfirmation,
                style: context.font.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const Gap(24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  BBButton.small(
                    label: context.loc.recoverbullGoogleDriveCancelButton,
                    onPressed: () => context.pop(),
                    bgColor: context.colour.secondary,
                    textColor: context.colour.onSecondary,
                  ),
                  BBButton.small(
                    label: context.loc.recoverbullGoogleDriveDeleteButton,
                    onPressed: () {
                      context.pop();
                      bloc.add(
                        OnDeleteDriveFile(fileMetadata: driveFileMetadata),
                      );
                    },
                    bgColor: context.colour.primary,
                    textColor: context.colour.onPrimary,
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
        overflow: TextOverflow.ellipsis,
      ),
      onTap:
          () => bloc.add(
            OnSelectDriveFileMetadata(fileMetadata: driveFileMetadata),
          ),
      onLongPress: () => _showActionsBottomSheet(context),
      enabled: !state.isLoading,
    );
  }
}
