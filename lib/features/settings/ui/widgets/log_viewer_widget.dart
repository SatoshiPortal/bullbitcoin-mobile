import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/log_entry.dart';
import 'package:bb_mobile/features/settings/presentation/logs_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/logs_state.dart';
import 'package:bb_mobile/features/settings/presentation/settings_failure_l10n.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/share_logs_bottom_sheet.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:go_router/go_router.dart';

class LogsViewerWidget extends StatefulWidget {
  const LogsViewerWidget({super.key});

  @override
  State<LogsViewerWidget> createState() => _LogsViewerScreenState();
}

class _LogsViewerScreenState extends State<LogsViewerWidget> {
  DateTime? _startDate;
  DateTime? _endDate;

  List<LogEntry> get _filteredLogs {
    // Copy: `widget.logs` is owned by the parent and may be aliased by
    // sibling widgets (share-logs etc.). `.sort()` mutates in place,
    // so without a copy the parent's list flips from `readLogs()`'s
    // ascending order to this widget's descending order after the
    // first build.
    final result = List<LogEntry>.of(context.read<LogsCubit>().state.entries);
    result.sort(
      (a, b) => b.timestamp == null || a.timestamp == null
          ? 0
          : b.timestamp!.compareTo(a.timestamp!),
    );

    if (_startDate == null && _endDate == null) return result;

    return result.where((log) {
      final timestamp = log.timestamp;
      if (timestamp == null) return false;

      if (_startDate != null && timestamp.isBefore(_startDate!)) return false;

      if (_endDate != null) {
        final endOfDay = DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
          23,
          59,
          59,
          999,
        );
        if (timestamp.isAfter(endOfDay)) return false;
      }

      return true;
    }).toList();
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  Future<void> _onShareTapped() async {
    await showLogsShareSheet(
      context: context,
      onShare: _shareLogs,
      onExport: _exportLogs,
    );
  }

  Future<void> _shareLogs() async {
    if (_filteredLogs.isEmpty) return;
    try {
      await context.read<LogsCubit>().share(_filteredLogs);
    } catch (_) {}
  }

  Future<void> _exportLogs() async {
    if (_filteredLogs.isEmpty) return;
    try {
      final result = await context.read<LogsCubit>().export(_filteredLogs);
      if (!context.mounted) return;
      switch (result) {
        case Ok(:final value):
          if (value) {
            SnackBarUtils.showSnackBar(
              context,
              context.loc.logsExportedMessage,
            );
          }
        case Err():
          SnackBarUtils.showSnackBar(
            context,
            context.loc.logsExportFailedMessage,
          );
      }
    } catch (e) {
      if (!context.mounted) return;
      SnackBarUtils.showSnackBar(context, context.loc.logsExportFailedMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LogsCubit>().state;
    if (state.status == LogsStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == LogsStatus.failure) {
      return Center(child: Text(state.failure!.toTranslated(context)));
    }
    final logs = _filteredLogs;

    return Column(
      children: [
        Column(
          crossAxisAlignment: .stretch,
          children: [
            BBButton.big(
              bgColor: context.appColors.secondary,
              textColor: context.appColors.onSecondary,
              outlined: true,
              onPressed: _selectDateRange,
              iconData: Icons.date_range,
              label: _startDate != null && _endDate != null
                  ? '${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}'
                  : context.loc.logsViewerFilterByDate,
            ),
            const Gap(8),
            Row(
              mainAxisAlignment: .spaceAround,
              children: [
                BBText(
                  context.loc.logsViewerShowingCount(
                    logs.length,
                    context.read<LogsCubit>().state.entries.length,
                  ),
                  style: context.font.bodySmall?.copyWith(
                    color: context.appColors.onSurface.withValues(alpha: 0.6),
                  ),
                  textAlign: .center,
                ),
                if (_startDate != null || _endDate != null) ...[
                  const Gap(8),
                  IconButton(
                    onPressed: _clearDateRange,
                    icon: Icon(Icons.clear, color: context.appColors.primary),
                    tooltip: context.loc.logsViewerClearFilter,
                  ),
                ],
              ],
            ),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: .vertical,
            child: SingleChildScrollView(
              scrollDirection: .horizontal,
              child: Column(
                crossAxisAlignment: .start,
                children: List.generate(logs.length, (index) {
                  final logLine = logs[index];
                  // color for level
                  Color iconColor = context.appColors.secondary;
                  {
                    final colorForLevel = switch (logLine.severity) {
                      LogSeverity.finest =>
                        context.appColors.success.withValues(alpha: 0.5),
                      LogSeverity.finer => context.appColors.success.withValues(
                        alpha: 0.7,
                      ),
                      LogSeverity.fine => context.appColors.success,
                      LogSeverity.config => context.appColors.textMuted,
                      LogSeverity.info => context.appColors.info,
                      LogSeverity.warning => context.appColors.warning,
                      LogSeverity.severe => context.appColors.error,
                      LogSeverity.shout => context.appColors.primary,
                      _ => context.appColors.textMuted,
                    };
                    iconColor = colorForLevel;
                  }

                  return Row(
                    children: [
                      IconButton(
                        onPressed: () => Clipboard.setData(
                          ClipboardData(text: logLine.rawLine),
                        ),
                        icon: Icon(Icons.copy, color: iconColor),
                      ),
                      SelectableText(
                        logLine.displayText,
                        style: context.font.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: context.appColors.onSurface,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: .spaceBetween,
          children: [
            BBButton.small(
              onPressed: () => _showConfirmDeleteLogsBottomSheet(context),
              label: context.loc.logsViewerDeleteButton,
              bgColor: context.appColors.primary,
              textColor: context.appColors.onPrimary,
            ),
            BBButton.small(
              bgColor: context.appColors.secondary,
              textColor: context.appColors.onSecondary,
              onPressed: _onShareTapped,
              label: context.loc.logsViewerShareButton,
            ),
          ],
        ),
        const Gap(16),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

Future<void> _showConfirmDeleteLogsBottomSheet(BuildContext context) async {
  await BlurredBottomSheet.show(
    context: context,
    child: Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.3,
      ),
      decoration: BoxDecoration(
        color: context.appColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const Gap(16),
            BBText(
              context.loc.logsViewerDeleteTitle,
              style: context.font.headlineMedium,
            ),
            const Gap(16),
            BBText(
              context.loc.logsViewerDeleteConfirmation,
              style: context.font.bodyMedium,
            ),
            const Gap(16),
            Row(
              mainAxisAlignment: .spaceEvenly,
              children: [
                BBButton.small(
                  onPressed: () async {
                    context.goNamed(WalletRoute.walletHome.name);
                    await context.read<LogsCubit>().delete();
                  },
                  label: context.loc.logsViewerDeleteButton,
                  bgColor: context.appColors.primary,
                  textColor: context.appColors.onPrimary,
                ),
                BBButton.small(
                  onPressed: () => context.pop(),
                  label: context.loc.logsViewerCancelButton,
                  bgColor: context.appColors.secondary,
                  textColor: context.appColors.onSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
