import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/themes/colors.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/settings/domain/log_entry.dart';
import 'package:bb_mobile/features/settings/presentation/logs_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/logs_state.dart';
import 'package:bb_mobile/features/settings/presentation/settings_failure_l10n.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class LogsViewerWidget extends StatefulWidget {
  const LogsViewerWidget({super.key});

  @override
  State<LogsViewerWidget> createState() => _LogsViewerWidgetState();
}

class _LogsViewerWidgetState extends State<LogsViewerWidget> {
  bool _expandAll = false;

  @override
  Widget build(BuildContext context) {
    // The diagnostic console intentionally stays dark in both app themes so
    // severity colors keep a stable, high-contrast meaning.
    final state = context.watch<LogsCubit>().state;
    if (state.status == LogsStatus.loading) {
      return ColoredBox(
        color: AppColors.dark.background,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.dark.primary),
        ),
      );
    }
    if (state.status == LogsStatus.failure) {
      return ColoredBox(
        color: AppColors.dark.background,
        child: Center(
          child: Text(
            state.failure!.toTranslated(context),
            style: TextStyle(color: AppColors.dark.onSurface),
          ),
        ),
      );
    }

    return ColoredBox(
      color: AppColors.dark.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: BBText(
                    context.loc.logsViewerShowingCount(
                      state.visibleEntries.length,
                      state.entries.length,
                    ),
                    style: context.font.bodySmall?.copyWith(
                      color: AppColors.dark.textMuted,
                    ),
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('logs-wrap-all'),
                  onPressed: () => setState(() => _expandAll = !_expandAll),
                  icon: Icon(
                    _expandAll ? Icons.compress : Icons.wrap_text,
                    color: AppColors.dark.onSurface,
                  ),
                  label: Text(
                    _expandAll
                        ? context.loc.logsViewerCollapseAll
                        : context.loc.logsViewerWrapAll,
                    style: TextStyle(color: AppColors.dark.onSurface),
                  ),
                ),
              ],
            ),
            Expanded(child: _buildLogList(context, state)),
          ],
        ),
      ),
    );
  }

  Widget _buildLogList(BuildContext context, LogsState state) =>
      RefreshIndicator(
        color: AppColors.dark.primary,
        backgroundColor: AppColors.dark.surface,
        onRefresh: () => _refreshLogs(context),
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: state.visibleEntries.isEmpty
              ? 1
              : state.visibleEntries.length,
          itemBuilder: (context, index) {
            if (state.visibleEntries.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: BBText(
                  state.entries.isEmpty
                      ? context.loc.logsViewerEmpty
                      : context.loc.logsViewerNoMatches,
                  style: context.font.bodyMedium?.copyWith(
                    color: AppColors.dark.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            }
            final entry = state.visibleEntries[index];
            return _LogLine(
              key: ValueKey(entry.rawLine),
              entry: entry,
              index: index,
              query: state.query,
              expandAll: _expandAll,
            );
          },
        ),
      );

  Future<void> _refreshLogs(BuildContext context) async {
    final result = await context.read<LogsCubit>().refresh();
    if (!context.mounted) return;
    if (result case Err(:final failure)) {
      SnackBarUtils.showSnackBar(context, failure.toTranslated(context));
    }
  }
}

Future<void> showLogsFilterSheet(BuildContext context) async {
  final cubit = context.read<LogsCubit>();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.dark.surface,
    barrierColor: AppColors.dark.transparent,
    builder: (_) =>
        BlocProvider.value(value: cubit, child: const _LogsFilterSheet()),
  );
}

final class _LogsFilterSheet extends StatefulWidget {
  const _LogsFilterSheet();

  @override
  State<_LogsFilterSheet> createState() => _LogsFilterSheetState();
}

final class _LogsFilterSheetState extends State<_LogsFilterSheet> {
  static const _searchDebounceDuration = Duration(milliseconds: 120);

  late final LogsCubit _cubit;
  late final TextEditingController _searchController;
  Timer? _searchDebounce;
  late String _pendingQuery;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<LogsCubit>();
    _pendingQuery = _cubit.state.query;
    _searchController = TextEditingController(text: _pendingQuery);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    if (_pendingQuery != _cubit.state.query) {
      _cubit.setQuery(_pendingQuery);
    }
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<LogsCubit, LogsState>(
    buildWhen: (previous, current) =>
        previous.entries != current.entries ||
        previous.severities != current.severities ||
        previous.startDate != current.startDate ||
        previous.endDate != current.endDate,
    builder: (context, state) {
      final availableSeverities = state.entries
          .map((entry) => entry.severity)
          .toSet();
      return AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.dark.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Gap(16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: LogSeverity.values
                    .where(
                      (severity) =>
                          severity != LogSeverity.unknown &&
                          availableSeverities.contains(severity),
                    )
                    .map(
                      (severity) =>
                          _buildSeverityChip(context, state, severity),
                    )
                    .toList(),
              ),
              const Gap(12),
              Row(
                children: [
                  Expanded(child: _buildDateButton(context, state)),
                  if (state.startDate != null || state.endDate != null) ...[
                    const Gap(4),
                    IconButton(
                      tooltip: context.loc.logsViewerClearFilter,
                      onPressed: () =>
                          context.read<LogsCubit>().setDateRange(null, null),
                      icon: Icon(Icons.clear, color: AppColors.dark.primary),
                    ),
                  ],
                ],
              ),
              const Gap(12),
              TextField(
                key: const ValueKey('logs-search'),
                controller: _searchController,
                onChanged: _onQueryChanged,
                cursorColor: AppColors.dark.onSurface,
                style: TextStyle(color: AppColors.dark.onSurface),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.dark.background,
                  hintText: context.loc.logsViewerSearchHint,
                  hintStyle: TextStyle(color: AppColors.dark.textMuted),
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppColors.dark.textMuted,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.dark.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.dark.onSurface),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  void _onQueryChanged(String query) {
    _pendingQuery = query;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDebounceDuration, () {
      if (mounted) _cubit.setQuery(_pendingQuery);
    });
  }

  Widget _buildSeverityChip(
    BuildContext context,
    LogsState state,
    LogSeverity severity,
  ) {
    final selected = state.severities.contains(severity);
    final color = _colorForSeverity(severity);
    return FilterChip(
      key: ValueKey('log-severity-${severity.name}'),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      backgroundColor: AppColors.dark.background,
      selectedColor: color.withValues(alpha: 0.2),
      side: BorderSide(color: selected ? color : AppColors.dark.border),
      avatar: Icon(Icons.circle, size: 8, color: color),
      label: Text(severity.name.toUpperCase()),
      labelStyle: TextStyle(color: selected ? color : AppColors.dark.onSurface),
      onSelected: (_) => context.read<LogsCubit>().toggleSeverity(severity),
    );
  }

  Widget _buildDateButton(
    BuildContext context,
    LogsState state,
  ) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.dark.onSurface,
      side: BorderSide(color: AppColors.dark.border),
    ),
    icon: const Icon(Icons.date_range),
    label: Text(
      state.startDate != null && state.endDate != null
          ? '${_formatDate(state.startDate!)} - ${_formatDate(state.endDate!)}'
          : context.loc.logsViewerFilterByDate,
    ),
    onPressed: () => _selectDateRange(context, state),
  );

  Future<void> _selectDateRange(BuildContext context, LogsState state) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: state.startDate == null
          ? null
          : DateTimeRange(
              start: state.startDate!,
              end: state.endDate ?? state.startDate!,
            ),
    );
    if (!context.mounted || range == null) return;
    context.read<LogsCubit>().setDateRange(range.start, range.end);
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}

class _LogLine extends StatefulWidget {
  final LogEntry entry;
  final int index;
  final String query;
  final bool expandAll;

  const _LogLine({
    required this.entry,
    required this.index,
    required this.query,
    required this.expandAll,
    super.key,
  });

  @override
  State<_LogLine> createState() => _LogLineState();
}

class _LogLineState extends State<_LogLine> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.expandAll;
  }

  @override
  void didUpdateWidget(_LogLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expandAll != widget.expandAll) {
      _expanded = widget.expandAll;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForSeverity(widget.entry.severity);
    final line = Semantics(
      container: true,
      button: true,
      expanded: _expanded,
      label: widget.entry.displayText,
      hint: _expanded
          ? context.loc.logsViewerCollapseHint
          : context.loc.logsViewerExpandHint,
      onTap: _toggleExpanded,
      onLongPress: _copy,
      child: ExcludeSemantics(
        child: GestureDetector(
          key: ValueKey('log-entry-${widget.index}'),
          behavior: HitTestBehavior.opaque,
          onTap: _toggleExpanded,
          onLongPress: _copy,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _expanded
                  ? AppColors.dark.surface
                  : AppColors.dark.transparent,
              border: BorderDirectional(
                start: BorderSide(
                  color: _expanded ? color : AppColors.dark.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Text.rich(
                _highlightedText(color),
                key: ValueKey('log-text-${widget.index}'),
                maxLines: _expanded ? null : 1,
                softWrap: _expanded,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (_expanded) return line;
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: line);
  }

  TextSpan _highlightedText(Color color) {
    final text = widget.entry.displayText;
    final query = widget.query.trim();
    if (query.isEmpty) return TextSpan(text: text);

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    while (start < text.length) {
      final match = lowerText.indexOf(lowerQuery, start);
      if (match == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (match > start) {
        spans.add(TextSpan(text: text.substring(start, match)));
      }
      spans.add(
        TextSpan(
          text: text.substring(match, match + query.length),
          style: TextStyle(
            color: AppColors.dark.onPrimary,
            backgroundColor: AppColors.dark.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      start = match + query.length;
    }
    return TextSpan(
      style: TextStyle(color: color),
      children: spans,
    );
  }

  void _toggleExpanded() => setState(() => _expanded = !_expanded);

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.entry.rawLine));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.loc.copiedToClipboardMessage)),
      );
    }
  }
}

Color _colorForSeverity(LogSeverity severity) => switch (severity) {
  LogSeverity.finest => AppColors.dark.success.withValues(alpha: 0.5),
  LogSeverity.finer => AppColors.dark.success.withValues(alpha: 0.7),
  LogSeverity.fine => AppColors.dark.success,
  LogSeverity.config => AppColors.dark.textMuted,
  LogSeverity.info => AppColors.dark.info,
  LogSeverity.warning => AppColors.dark.warning,
  LogSeverity.severe => AppColors.dark.error,
  LogSeverity.shout => AppColors.dark.primary,
  LogSeverity.unknown => AppColors.dark.textMuted,
};

Future<void> showConfirmDeleteLogsBottomSheet(BuildContext context) async {
  await BlurredBottomSheet.show(
    context: context,
    child: Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.3,
      ),
      color: AppColors.dark.background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const Gap(16),
            BBText(
              context.loc.logsViewerDeleteTitle,
              style: context.font.headlineMedium?.copyWith(
                color: AppColors.dark.onSurface,
              ),
            ),
            const Gap(16),
            BBText(
              context.loc.logsViewerDeleteConfirmation,
              style: context.font.bodyMedium?.copyWith(
                color: AppColors.dark.onSurface,
              ),
            ),
            const Gap(16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                BBButton.small(
                  onPressed: () async {
                    final result = await context.read<LogsCubit>().delete();
                    if (!context.mounted) return;
                    context.pop();
                    switch (result) {
                      case Ok():
                        SnackBarUtils.showSnackBar(
                          context,
                          context.loc.logsDeletedMessage,
                        );
                      case Err(:final failure):
                        SnackBarUtils.showSnackBar(
                          context,
                          failure.toTranslated(context),
                        );
                    }
                  },
                  label: context.loc.logsViewerDeleteButton,
                  bgColor: AppColors.dark.primary,
                  textColor: AppColors.dark.onPrimary,
                ),
                BBButton.small(
                  onPressed: context.pop,
                  label: context.loc.logsViewerCancelButton,
                  bgColor: AppColors.dark.surface,
                  textColor: AppColors.dark.onSurface,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
