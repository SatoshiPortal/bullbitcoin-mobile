import '../../../domain/entities/drive_file_metadata.dart';
import '../../presentation/bloc.dart';
import '../../presentation/event.dart';
import '../../../presentation/recoverbull_failure_l10n.dart';
import '../../presentation/state.dart';
import '../../../l10n/context_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
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

    return BullScaffold(
      appBar: BullTopBar.appBar(
        titleStyle: context.bullText.headlineMedium,
        title: context.loc.recoverbullGoogleDriveScreenTitle,
        onBack: () => context.pop(),
        materialTransparency: true,
      ),
      body: Column(
        children: [
          BullFadingLinearProgress(
            trigger: state.isLoading,
            foregroundColor: context.bull.primary,
            height: 2.0,
          ),
          Expanded(
            child: failure != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(failure.toTranslated(context)),
                        const Gap(BullSpacing.sm),
                        BullButton.small(
                          label: context.loc.recoverbullRetry,
                          onPressed: () => context
                              .read<RecoverBullGoogleDriveBloc>()
                              .add(const OnFetchDriveVaults()),
                          bgColor: context.bull.onSurface,
                          textColor: context.bull.surface,
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
    BullBottomSheet.show(
      context: context,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.4,
        ),
        decoration: BoxDecoration(
          color: context.bull.onSecondary,
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
                    bgColor: context.bull.secondary,
                    textColor: context.bull.onSecondary,
                  ),
                  BullButton.small(
                    label: context.loc.recoverbullGoogleDriveDeleteButton,
                    onPressed: () {
                      context.pop();
                      _showDeleteConfirmationBottomSheet(context);
                    },
                    bgColor: context.bull.primary,
                    textColor: context.bull.onPrimary,
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
          color: context.bull.onSecondary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisSize: .min,
            children: [
              BullText(
                context.loc.recoverbullGoogleDriveDeleteVaultTitle,
                style: context.bullText.headlineMedium,
              ),
              const Gap(BullSpacing.md),
              BullText(
                context.loc.recoverbullGoogleDriveDeleteConfirmation,
                style: context.bullText.bodyMedium,
                textAlign: .center,
              ),
              const Gap(BullSpacing.lg),
              Row(
                mainAxisAlignment: .spaceEvenly,
                children: [
                  BullButton.small(
                    label: context.loc.recoverbullGoogleDriveCancelButton,
                    onPressed: () => context.pop(),
                    bgColor: context.bull.secondary,
                    textColor: context.bull.onSecondary,
                  ),
                  BullButton.small(
                    label: context.loc.recoverbullGoogleDriveDeleteButton,
                    onPressed: () {
                      context.pop();
                      bloc.add(
                        OnDeleteDriveFile(fileMetadata: driveFileMetadata),
                      );
                    },
                    bgColor: context.bull.primary,
                    textColor: context.bull.onPrimary,
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

    return BullBorderedTile(
      onTap: state.isLoading
          ? null
          : () => bloc.add(
              OnSelectDriveFileMetadata(fileMetadata: driveFileMetadata),
            ),
      onLongPress: state.isLoading
          ? null
          : () => _showActionsBottomSheet(context),
      child: BullText(
        '${DateFormat('MMM dd, yyyy • HH:mm').format(driveFileMetadata.createdTime.toLocal())} • ${driveFileMetadata.name}',
        style: context.bullText.bodyMedium,
        color: state.isLoading
            ? context.bull.textMuted
            : context.bull.onSurface,
        maxLines: 2,
        overflow: .ellipsis,
      ),
    );
  }
}
