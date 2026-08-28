import 'dart:async';

import 'package:bull_logs/generated/l10n/logs_localizations.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_logs/src/domain/log_entry.dart';
import 'package:bull_logs/src/presentation/logs_cubit.dart';
import 'package:bull_logs/src/presentation/logs_state.dart';
import '../presentation/logs_failure_l10n.dart';
import 'package:bull_ui/bull_ui.dart';
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
        color: context.bull.background,
        child: Center(
          child: CircularProgressIndicator(color: context.bull.primary),
        ),
      );
    }
    if (state.status == LogsStatus.failure) {
      return ColoredBox(
        color: context.bull.background,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.failure!.toTranslated(context),
                style: TextStyle(color: context.bull.onSurface),
              ),
              const Gap(12),
              BullButton.small(
                key: const ValueKey('logs-retry'),
                bgColor: context.bull.primary,
                textColor: context.bull.onPrimary,
                label: LogsLocalizations.of(context).retry,
                onPressed: () => _refreshLogs(context),
              ),
            ],
          ),
        ),
      );
    }

    return ColoredBox(
      color: context.bull.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    LogsLocalizations.of(context).logsViewerShowingCount(
                      state.visibleEntries.length,
                      state.entries.length,
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.bull.textMuted,
                    ),
                  ),
                ),
                BullViewerActionButton(
                  key: const ValueKey('logs-wrap-all'),
                  onTap: () => setState(() => _expandAll = !_expandAll),
                  icon: _expandAll ? Icons.compress : Icons.wrap_text,
                  label: _expandAll
                      ? LogsLocalizations.of(context).logsViewerCollapseAll
                      : LogsLocalizations.of(context).logsViewerWrapAll,
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
      BullRefreshIndicator(
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
                child: Text(
                  state.entries.isEmpty
                      ? LogsLocalizations.of(context).logsViewerEmpty
                      : LogsLocalizations.of(context).logsViewerNoMatches,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.bull.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            }
            final entry = state.visibleEntries[index];
            return _LogLine(
              key: ObjectKey(entry),
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
      BullSnackBar.show(context, message: failure.toTranslated(context));
    }
  }
}

Future<void> showLogsFilterSheet(BuildContext context) async {
  final cubit = context.read<LogsCubit>();
  await BullBottomSheet.show<void>(
    context: context,
    child: BlocProvider.value(value: cubit, child: const _LogsFilterSheet()),
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
                    color: context.bull.textMuted,
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
                      tooltip: LogsLocalizations.of(
                        context,
                      ).logsViewerClearFilter,
                      onPressed: () =>
                          context.read<LogsCubit>().setDateRange(null, null),
                      icon: Icon(Icons.clear, color: context.bull.primary),
                    ),
                  ],
                ],
              ),
              const Gap(12),
              BullInputText(
                uiKey: const ValueKey('logs-search'),
                controller: _searchController,
                value: _pendingQuery,
                onChanged: _onQueryChanged,
                hint: LogsLocalizations.of(context).logsViewerSearchHint,
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
    final color = _colorForSeverity(context, severity);
    return BullFilterChip.selectable(
      key: ValueKey('log-severity-${severity.name}'),
      label: severity.name.toUpperCase(),
      selected: selected,
      selectionColor: color,
      onSelected: (_) => context.read<LogsCubit>().toggleSeverity(severity),
    );
  }

  Widget _buildDateButton(
    BuildContext context,
    LogsState state,
  ) => BullButton.small(
    width: double.infinity,
    iconData: Icons.date_range,
    bgColor: context.bull.surface,
    textColor: context.bull.onSurface,
    outlined: true,
    borderColor: context.bull.border,
    label: state.startDate != null && state.endDate != null
        ? '${_formatDate(state.startDate!)} - ${_formatDate(state.endDate!)}'
        : LogsLocalizations.of(context).logsViewerFilterByDate,
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
    final color = _colorForSeverity(context, widget.entry.severity);
    final line = Semantics(
      container: true,
      button: true,
      expanded: _expanded,
      label: widget.entry.displayText,
      hint: _expanded
          ? LogsLocalizations.of(context).logsViewerCollapseHint
          : LogsLocalizations.of(context).logsViewerExpandHint,
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
                  ? context.bull.surface
                  : context.bull.transparent,
              border: BorderDirectional(
                start: BorderSide(
                  color: _expanded ? color : context.bull.transparent,
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
            color: context.bull.onPrimary,
            backgroundColor: context.bull.primary,
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
        SnackBar(
          content: Text(LogsLocalizations.of(context).copiedToClipboardMessage),
        ),
      );
    }
  }
}

Color _colorForSeverity(BuildContext context, LogSeverity severity) =>
    switch (severity) {
      LogSeverity.finest => context.bull.success.withValues(alpha: 0.5),
      LogSeverity.finer => context.bull.success.withValues(alpha: 0.7),
      LogSeverity.fine => context.bull.success,
      LogSeverity.config => context.bull.textMuted,
      LogSeverity.info => context.bull.info,
      LogSeverity.warning => context.bull.warning,
      LogSeverity.severe => context.bull.error,
      LogSeverity.shout => context.bull.primary,
      LogSeverity.unknown => context.bull.textMuted,
    };

Future<void> showConfirmDeleteLogsBottomSheet(BuildContext context) async {
  await BullBottomSheet.show(
    context: context,
    child: Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.3,
      ),
      color: context.bull.background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const Gap(16),
            Text(
              LogsLocalizations.of(context).logsViewerDeleteTitle,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: context.bull.onSurface,
              ),
            ),
            const Gap(16),
            Text(
              LogsLocalizations.of(context).logsViewerDeleteConfirmation,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: context.bull.onSurface),
            ),
            const Gap(16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                BullButton.small(
                  onPressed: () async {
                    final result = await context.read<LogsCubit>().delete();
                    if (!context.mounted) return;
                    context.pop();
                    switch (result) {
                      case Ok():
                        BullSnackBar.show(
                          context,
                          message: LogsLocalizations.of(
                            context,
                          ).logsDeletedMessage,
                        );
                      case Err(:final failure):
                        BullSnackBar.show(
                          context,
                          message: failure.toTranslated(context),
                        );
                    }
                  },
                  label: LogsLocalizations.of(context).logsViewerDeleteButton,
                  bgColor: context.bull.primary,
                  textColor: context.bull.onPrimary,
                ),
                BullButton.small(
                  onPressed: context.pop,
                  label: LogsLocalizations.of(context).logsViewerCancelButton,
                  bgColor: context.bull.surface,
                  textColor: context.bull.onSurface,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
