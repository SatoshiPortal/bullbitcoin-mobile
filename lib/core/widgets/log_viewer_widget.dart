import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

class LogsViewerWidget extends StatefulWidget {
  final List<String> logs;

  const LogsViewerWidget({super.key, required this.logs});

  @override
  State<LogsViewerWidget> createState() => _LogsViewerScreenState();
}

class _LogsViewerScreenState extends State<LogsViewerWidget> {
  DateTime? _startDate;
  DateTime? _endDate;

  List<String> get _filteredLogs {
    final result = widget.logs;
    result.sort((a, b) {
      final partsA = a.split('\t');
      final partsB = b.split('\t');
      return partsB[0].compareTo(partsA[0]);
    });

    if (_startDate == null && _endDate == null) return result;

    return result.where((log) {
      final parts = log.split('\t');
      if (parts.isEmpty) return false;

      try {
        final timestamp = DateTime.parse(parts[0]);

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
      } catch (e) {
        return false;
      }
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

  Future<void> _shareLogs() async {
    if (_filteredLogs.isEmpty) return;
    final logsToShare = _filteredLogs.join('\n');
    await SharePlus.instance.share(
      ShareParams(
        text: logsToShare,
        subject: 'bull_logs.tsv',
        title: 'bull_logs.tsv',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logs = _filteredLogs;

    return Column(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BBButton.big(
              bgColor: context.appColors.secondary,
              textColor: context.appColors.onSecondary,
              outlined: true,
              onPressed: _selectDateRange,
              iconData: Icons.date_range,
              label:
                  _startDate != null && _endDate != null
                      ? '${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}'
                      : 'Filter by Date',
            ),
            const Gap(8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                BBText(
                  'Showing ${logs.length} of ${widget.logs.length} logs',
                  style: context.font.bodySmall?.copyWith(
                    color: context.appColors.onSurface.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_startDate != null || _endDate != null) ...[
                  const Gap(8),
                  IconButton(
                    onPressed: _clearDateRange,
                    icon: Icon(Icons.clear, color: context.appColors.primary),
                    tooltip: 'Clear filter',
                  ),
                ],
              ],
            ),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(logs.length, (index) {
                  final logLine = logs[index];
                  final parts = logLine.split('\t');

                  // color for level
                  Color iconColor = context.appColors.secondary;
                  if (parts.length > 1) {
                    final colorForLevel = switch (parts[1]) {
                      'FINEST' => context.appColors.success.withValues(alpha: 0.5),
                      'FINER' => context.appColors.success.withValues(alpha: 0.7),
                      'FINE' => context.appColors.success,
                      'CONFIG' => context.appColors.textMuted,
                      'INFO' => context.appColors.info,
                      'WARNING' => context.appColors.warning,
                      'SEVERE' => context.appColors.error,
                      'SHOUT' => context.appColors.primary,
                      _ => context.appColors.textMuted,
                    };
                    iconColor = colorForLevel;
                  }

                  // remove milliseconds from datetime
                  final displayParts = parts.toList();
                  if (displayParts.isNotEmpty && displayParts[0].length > 7) {
                    try {
                      displayParts[0] = displayParts[0].substring(
                        0,
                        displayParts[0].length - 7,
                      );
                    } catch (_) {}
                  }
                  final displayText = displayParts.join(' | ');

                  return Row(
                    children: [
                      IconButton(
                        onPressed:
                            () =>
                                Clipboard.setData(ClipboardData(text: logLine)),
                        icon: Icon(Icons.copy, color: iconColor),
                      ),
                      SelectableText(
                        displayText,
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            BBButton.small(
              onPressed: () => _showConfirmDeleteLogsBottomSheet(context),
              label: 'Delete',
              bgColor: context.appColors.primary,
              textColor: context.appColors.onPrimary,
            ),
            BBButton.small(
              bgColor: context.appColors.secondary,
              textColor: context.appColors.onSecondary,
              onPressed: _shareLogs,
              label: 'Share',
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
        color: context.appColors.onPrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const Gap(16),
            BBText('Delete logs', style: context.font.headlineMedium),
            const Gap(16),
            BBText(
              'Are you sure you want to delete all logs? This action cannot be undone.',
              style: context.font.bodyMedium,
            ),
            const Gap(16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                BBButton.small(
                  onPressed: () async {
                    context.goNamed(WalletRoute.walletHome.name);
                    await log.deleteLogs();
                  },
                  label: 'Delete',
                  bgColor: context.appColors.primary,
                  textColor: context.appColors.onPrimary,
                ),
                BBButton.small(
                  onPressed: () => context.pop(),
                  label: 'Cancel',
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
