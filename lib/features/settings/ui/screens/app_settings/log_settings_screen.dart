import 'package:bb_mobile/core/themes/colors.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/widgets/share_logs_bottom_sheet.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/settings/presentation/logs_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/logs_state.dart';
import 'package:bb_mobile/features/settings/ui/widgets/log_viewer_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

class LogSettingsScreen extends StatelessWidget {
  const LogSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => GetIt.I<LogsCubit>()..load(),
    child: const _LogSettingsView(),
  );
}

final class _LogSettingsView extends StatelessWidget {
  const _LogSettingsView();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: AppColors.dark.background,
      foregroundColor: AppColors.dark.onSurface,
      surfaceTintColor: AppColors.dark.background,
      scrolledUnderElevation: 0,
      title: Text(
        context.loc.logSettingsLogsTitle,
        style: TextStyle(color: AppColors.dark.onSurface),
      ),
      actions: [
        IconButton(
          key: const ValueKey('logs-delete'),
          tooltip: context.loc.logsViewerDeleteButton,
          icon: const Icon(Icons.delete_outline),
          onPressed: () => showConfirmDeleteLogsBottomSheet(context),
        ),
        BlocBuilder<LogsCubit, LogsState>(
          buildWhen: (previous, current) =>
              previous.query != current.query ||
              previous.severities != current.severities ||
              previous.startDate != current.startDate ||
              previous.endDate != current.endDate,
          builder: (context, state) {
            final hasActiveFilters =
                state.query.isNotEmpty ||
                state.severities.isNotEmpty ||
                state.startDate != null ||
                state.endDate != null;
            return IconButton(
              key: const ValueKey('logs-filter'),
              tooltip: context.loc.logsViewerFilter,
              icon: Icon(
                Icons.tune,
                color: hasActiveFilters
                    ? AppColors.dark.primary
                    : AppColors.dark.onSurface,
              ),
              onPressed: () => showLogsFilterSheet(context),
            );
          },
        ),
        IconButton(
          key: const ValueKey('logs-share'),
          tooltip: context.loc.logsViewerShareButton,
          icon: const Icon(Icons.share),
          onPressed: () => _showShareSheet(context),
        ),
      ],
    ),
    body: const SafeArea(child: LogsViewerWidget()),
  );

  Future<void> _showShareSheet(BuildContext context) => showLogsShareSheet(
    context: context,
    onShare: () => _share(context),
    onExport: () => _export(context),
  );

  Future<void> _share(BuildContext context) async {
    final cubit = context.read<LogsCubit>();
    final result = await cubit.share(cubit.state.visibleEntries);
    if (!context.mounted) return;
    if (result case Err()) {
      SnackBarUtils.showSnackBar(context, context.loc.logsShareFailedMessage);
    }
  }

  Future<void> _export(BuildContext context) async {
    final cubit = context.read<LogsCubit>();
    final result = await cubit.export(cubit.state.visibleEntries);
    if (!context.mounted) return;
    switch (result) {
      case Ok(value: true):
        SnackBarUtils.showSnackBar(context, context.loc.logsExportedMessage);
      case Ok():
        return;
      case Err():
        SnackBarUtils.showSnackBar(
          context,
          context.loc.logsExportFailedMessage,
        );
    }
  }
}
