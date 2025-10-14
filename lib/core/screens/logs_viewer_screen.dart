import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:share_plus/share_plus.dart';

class LogsViewerScreen extends StatefulWidget {
  final List<String> logs;

  const LogsViewerScreen({super.key, required this.logs});

  @override
  State<LogsViewerScreen> createState() => _LogsViewerScreenState();
}

class _LogsViewerScreenState extends State<LogsViewerScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  List<String> get _filteredLogs {
    if (_startDate == null && _endDate == null) {
      return widget.logs;
    }

    return widget.logs.where((log) {
      final parts = log.split('\t');
      if (parts.isEmpty) return false;

      try {
        final timestamp = DateTime.parse(parts[0]);

        if (_startDate != null && timestamp.isBefore(_startDate!)) {
          return false;
        }

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
    final filteredLogs = _filteredLogs.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          IconButton(
            onPressed: _shareLogs,
            icon: const Icon(Icons.share),
            tooltip: 'Share logs',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: context.colour.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BBButton.big(
                  bgColor: context.colour.secondary,
                  textColor: context.colour.onSecondary,
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    BBText(
                      'Showing ${filteredLogs.length} of ${widget.logs.length} logs',
                      style: context.font.bodySmall?.copyWith(
                        color: context.colour.onSurface.withValues(alpha: 0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_startDate != null || _endDate != null) ...[
                      const Gap(8),
                      IconButton(
                        onPressed: _clearDateRange,
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear filter',
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(filteredLogs.length, (index) {
                    final logLine = filteredLogs[index];
                    final parts = logLine.split('\t');

                    Color iconColor = context.colour.secondary;
                    if (parts.length > 1) {
                      final colorForLevel = switch (parts[1]) {
                        'FINEST' => Colors.lightGreenAccent,
                        'FINER' => Colors.lightGreen,
                        'FINE' => Colors.green,
                        'CONFIG' => Colors.brown,
                        'INFO' => Colors.blue,
                        'WARNING' => Colors.orange,
                        'SEVERE' => Colors.red,
                        'SHOUT' => Colors.purple,
                        _ => throw Exception('Invalid log level: ${parts[1]}'),
                      };
                      iconColor = colorForLevel;
                    }

                    return Row(
                      children: [
                        IconButton(
                          onPressed:
                              () => Clipboard.setData(
                                ClipboardData(text: logLine),
                              ),
                          icon: Icon(Icons.copy, color: iconColor),
                        ),
                        SelectableText(
                          logLine.replaceAll('\t', ' | '),
                          style: context.font.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: context.colour.onSurface,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
