import 'package:bull_logs/generated/l10n/logs_localizations.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_logs/src/ui/share_logs_bottom_sheet.dart';
import 'package:bull_logs/src/presentation/logs_cubit.dart';
import 'package:bull_logs/src/presentation/logs_state.dart';
import 'log_viewer_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';

class LogSettingsScreen extends StatelessWidget {
  const LogSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => const _LogSettingsView();
}

final class _LogSettingsView extends StatelessWidget {
  const _LogSettingsView();

  @override
  Widget build(BuildContext context) => BullScaffold(
    appBar: AppBar(
      backgroundColor: context.bull.background,
      foregroundColor: context.bull.onSurface,
      surfaceTintColor: context.bull.background,
      scrolledUnderElevation: 0,
      title: Text(
        LogsLocalizations.of(context).logSettingsLogsTitle,
        style: TextStyle(color: context.bull.onSurface),
      ),
      actions: [
        IconButton(
          key: const ValueKey('logs-delete'),
          tooltip: LogsLocalizations.of(context).logsViewerDeleteButton,
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
              tooltip: LogsLocalizations.of(context).logsViewerFilter,
              icon: Icon(
                Icons.tune,
                color: hasActiveFilters
                    ? context.bull.primary
                    : context.bull.onSurface,
              ),
              onPressed: () => showLogsFilterSheet(context),
            );
          },
        ),
        IconButton(
          key: const ValueKey('logs-share'),
          tooltip: LogsLocalizations.of(context).logsViewerShareButton,
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
      BullSnackBar.show(
        context,
        message: LogsLocalizations.of(context).logsShareFailedMessage,
      );
    }
  }

  Future<void> _export(BuildContext context) async {
    final cubit = context.read<LogsCubit>();
    final result = await cubit.export(cubit.state.visibleEntries);
    if (!context.mounted) return;
    switch (result) {
      case Ok(value: final saved):
        if (!saved) return;
        BullSnackBar.show(
          context,
          message: LogsLocalizations.of(context).logsExportedMessage,
        );
      case Err():
        BullSnackBar.show(
          context,
          message: LogsLocalizations.of(context).logsExportFailedMessage,
        );
    }
  }
}
