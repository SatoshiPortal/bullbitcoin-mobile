import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/themes/fonts.dart';
import 'package:bb_mobile/core/utils/transaction_day_label.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';

/// Items grouped by day, each group under its day label.
///
/// The caller owns the item type and its row, so this widget stays free of
/// feature imports.
class TransactionsByDayList<T> extends StatelessWidget {
  const TransactionsByDayList({
    super.key,
    required this.itemsByDay,
    required this.itemBuilder,
    required this.loadingMessage,
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
  final String emptyMessage;

  /// Rendered above the first day group, and counts as content: while it is
  /// set the list never shows [emptyMessage].
  final Widget? header;
  final String? errorMessage;

  /// When true, returns Sliver* widgets so the list can live inside a
  /// CustomScrollView and share the parent's scroll/refresh gesture.
  final bool sliver;

  /// Label for a group key that is not a day; null falls back to
  /// [transactionDayLabel].
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
              BBText(
                errorMessage!,
                maxLines: 2,
                textAlign: .center,
                style: AppFonts.textTheme.textTheme.bodyMedium?.copyWith(
                  color: context.appColors.error,
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
              BBText(
                loadingMessage,
                maxLines: 2,
                textAlign: .center,
                style: AppFonts.textTheme.textTheme.bodyMedium?.copyWith(
                  color: context.appColors.onSurface,
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
              BBText(
                emptyMessage,
                maxLines: 2,
                textAlign: .center,
                style: AppFonts.textTheme.textTheme.bodyMedium?.copyWith(
                  color: context.appColors.onSurface,
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
            BBText(
              dayLabel?.call(context, entry.key) ??
                  transactionDayLabel(context, date),
              style: context.font.titleSmall?.copyWith(
                color: context.appColors.onSurface,
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
}
