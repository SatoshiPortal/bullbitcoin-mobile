import 'package:bull_ui/src/data_display/bull_date_locale.dart';
import 'package:bull_ui/src/data_display/bull_text.dart';
import 'package:bull_ui/src/layout/gap.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_typography.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

/// Items grouped by day, each group under its day label.
///
/// The caller owns the item type and its row, so this widget stays free of
/// feature imports.
class BullTransactionsByDayList<T> extends StatelessWidget {
  const BullTransactionsByDayList({
    super.key,
    required this.itemsByDay,
    required this.itemBuilder,
    required this.loadingMessage,
    required this.pendingLabel,
    required this.todayLabel,
    required this.yesterdayLabel,
    required this.emptyMessage,
    this.header,
    this.errorMessage,
    this.sliver = false,
    this.dayLabel,
  });

  /// Items keyed by the day's epoch milliseconds. Null means still loading.
  final Map<int, List<T>>? itemsByDay;
  final Widget Function(BuildContext, T) itemBuilder;
  final String loadingMessage;
  final String pendingLabel;
  final String todayLabel;
  final String yesterdayLabel;
  final String emptyMessage;

  /// Rendered above the first day group, and counts as content: while it is
  /// set the list never shows [emptyMessage].
  final Widget? header;
  final String? errorMessage;

  /// When true, returns Sliver* widgets so the list can live inside a
  /// CustomScrollView and share the parent's scroll/refresh gesture.
  final bool sliver;

  /// Label for a group key that is not a day; null falls back to
  /// [_transactionDayLabel].
  final String? Function(BuildContext, int dayKey)? dayLabel;

  Widget _wrapPlaceholder(Widget child) =>
      sliver ? SliverToBoxAdapter(child: child) : child;

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return _wrapPlaceholder(
        Center(
          child: Column(
            children: [
              const Gap(16),
              BullText(
                errorMessage!,
                maxLines: 2,
                textAlign: .center,
                style: context.bullType.body.copyWith(
                  color: context.bull.error,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (itemsByDay == null) {
      return _wrapPlaceholder(
        Center(
          child: Column(
            children: [
              const Gap(16),
              BullText(
                loadingMessage,
                maxLines: 2,
                textAlign: .center,
                style: context.bullType.body.copyWith(
                  color: context.bull.onSurface,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (itemsByDay!.isEmpty && header == null) {
      return _wrapPlaceholder(
        Center(
          child: Column(
            children: [
              const Gap(16),
              BullText(
                emptyMessage,
                maxLines: 2,
                textAlign: .center,
                style: context.bullType.body.copyWith(
                  color: context.bull.onSurface,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final hasHeader = header != null;
      final itemCount = itemsByDay!.entries.length + (hasHeader ? 1 : 0);
      Widget dayBuilder(BuildContext context, int index) {
        if (hasHeader && index == 0) return header!;

        final entry = itemsByDay!.entries.elementAt(
          hasHeader ? index - 1 : index,
        );
        final date = DateTime.fromMillisecondsSinceEpoch(entry.key);

        return Column(
          crossAxisAlignment: .start,
          children: [
            Semantics(
              header: true,
              child: BullText(
                dayLabel?.call(context, entry.key) ??
                    _transactionDayLabel(context, date),
                style: context.bullType.label.copyWith(
                  color: context.bull.onSurface,
                ),
              ),
            ),
            const Gap(16),
            ...entry.value.map((item) => itemBuilder(context, item)),
            const Gap(16),
          ],
        );
      }

      if (sliver) {
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          sliver: SliverList.builder(
            itemCount: itemCount,
            itemBuilder: dayBuilder,
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: itemCount,
        itemBuilder: dayBuilder,
      );
    }
  }

  /// Header for a day group in a transaction list: the pending bucket, the two
  /// most recent days by name, then a date that keeps the year only once it is
  /// no longer the current one.
  String _transactionDayLabel(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    if (date.compareTo(today) > 0) return pendingLabel;
    if (date.isAtSameMomentAs(today)) return todayLabel;
    if (date.isAtSameMomentAs(yesterday)) {
      return yesterdayLabel;
    }
    return date.year == now.year
        ? DateFormat.MMMMd(bullDateLocale(context)).format(date)
        : DateFormat.yMMMMd(bullDateLocale(context)).format(date);
  }
}
