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
    final result = widget.logs.toList();
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

  Color _colorForLevel(String level) {
    return switch (level) {
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
  }

  @override
  Widget build(BuildContext context) {
    final logs = _filteredLogs;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              BBText(
                '${logs.length} entries',
                style: context.font.labelSmall,
                color: context.appColors.textMuted,
              ),
              Row(
                children: [
                  if (_startDate != null || _endDate != null)
                    IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: context.appColors.textMuted,
                        size: 20,
                      ),
                      onPressed: _clearDateRange,
                    ),
                  IconButton(
                    icon: Icon(
                      Icons.date_range,
                      color: context.appColors.primary,
                      size: 20,
                    ),
                    onPressed: _selectDateRange,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.share,
                      color: context.appColors.primary,
                      size: 20,
                    ),
                    onPressed: _shareLogs,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: context.appColors.textMuted,
                      size: 20,
                    ),
                    onPressed: () => _showConfirmDeleteLogsBottomSheet(context),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: logs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.article_outlined,
                        size: 48,
                        color: context.appColors.textMuted.withValues(alpha: 0.3),
                      ),
                      const Gap(16),
                      BBText(
                        'No logs yet',
                        style: context.font.bodyMedium,
                        color: context.appColors.textMuted,
                      ),
                    ],
                  ),
                )
              : _LogsList(
                  logs: logs,
                  colorForLevel: _colorForLevel,
                ),
        ),
      ],
    );
  }

}

class _LogsList extends StatelessWidget {
  const _LogsList({
    required this.logs,
    required this.colorForLevel,
  });

  final List<String> logs;
  final Color Function(String) colorForLevel;

  static const double _itemHeight = 80.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final visibleCount = (constraints.maxHeight / _itemHeight).floor();
        final pageCount = (logs.length / visibleCount).ceil();

        return PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: pageCount,
          itemBuilder: (context, pageIndex) {
            final startIndex = pageIndex * visibleCount;
            final endIndex = (startIndex + visibleCount).clamp(0, logs.length);
            final pageItems = logs.sublist(startIndex, endIndex);

            return Column(
              children: pageItems.map((logLine) {
                return SizedBox(
                  height: _itemHeight,
                  child: _LogEntryTile(
                    logLine: logLine,
                    colorForLevel: colorForLevel,
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}

class _LogEntryTile extends StatelessWidget {
  const _LogEntryTile({
    required this.logLine,
    required this.colorForLevel,
  });

  final String logLine;
  final Color Function(String) colorForLevel;

  @override
  Widget build(BuildContext context) {
    final parts = logLine.split('\t');
    final timestamp = parts.isNotEmpty ? parts[0] : '';
    final level = parts.length > 1 ? parts[1] : '';
    final message = parts.length > 2 ? parts.sublist(2).join(' ') : '';
    final color = colorForLevel(level);

    String formattedTime = '';
    try {
      final dt = DateTime.parse(timestamp);
      formattedTime =
          '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      formattedTime = timestamp;
    }

    return GestureDetector(
      onTap: () => _showLogDetailSheet(context, logLine, level, color),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const Gap(8),
                Text(
                  level,
                  style: context.font.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
                const Spacer(),
                Text(
                  formattedTime,
                  style: context.font.labelSmall?.copyWith(
                    color: context.appColors.textMuted.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const Gap(6),
            Expanded(
              child: Text(
                message,
                style: context.font.bodySmall?.copyWith(
                  color: context.appColors.text,
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showLogDetailSheet(
  BuildContext context,
  String logLine,
  String level,
  Color color,
) async {
  await BlurredBottomSheet.show(
    context: context,
    child: Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: BoxDecoration(
        color: context.appColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Gap(8),
          Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: context.appColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Gap(16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const Gap(8),
                Text(
                  level,
                  style: context.font.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.copy,
                    size: 20,
                    color: context.appColors.textMuted,
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: logLine));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Log copied'),
                        duration: const Duration(seconds: 1),
                        backgroundColor: context.appColors.surfaceContainer,
                      ),
                    );
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
          const Gap(8),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SelectableText(
                logLine.replaceAll('\t', '\n'),
                style: context.font.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: context.appColors.text,
                  height: 1.5,
                ),
              ),
            ),
          ),
          const Gap(16),
        ],
      ),
    ),
  );
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
