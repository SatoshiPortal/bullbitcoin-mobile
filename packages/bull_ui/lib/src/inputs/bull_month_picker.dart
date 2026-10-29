import 'package:bull_ui/src/data_display/bull_text.dart';
import 'package:bull_ui/src/inputs/bull_dropdown.dart';
import 'package:bull_ui/src/layout/gap.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:flutter/material.dart';

/// A calendar-month selector. Bounds are inclusive and never include a future
/// month. The host supplies locale-aware month names and translated labels.
class BullMonthPicker extends StatefulWidget {
  /// Null leaves the month unselected and starts with the latest year.
  final DateTime? value;
  final DateTime now;
  final DateTime earliest;
  final DateTime? latest;
  final String monthLabel;
  final String yearLabel;
  final String Function(DateTime) monthName;
  final ValueChanged<DateTime> onChanged;

  const BullMonthPicker({
    super.key,
    required this.value,
    required this.now,
    required this.earliest,
    this.latest,
    required this.monthLabel,
    required this.yearLabel,
    required this.monthName,
    required this.onChanged,
  });

  @override
  State<BullMonthPicker> createState() => _BullMonthPickerState();
}

class _BullMonthPickerState extends State<BullMonthPicker> {
  int? _year;

  @override
  Widget build(BuildContext context) {
    final currentMonth = DateTime.utc(widget.now.year, widget.now.month);
    final requestedLatest = widget.latest;
    final maximum =
        requestedLatest != null && requestedLatest.isBefore(currentMonth)
        ? DateTime.utc(requestedLatest.year, requestedLatest.month)
        : currentMonth;
    final minimum = DateTime.utc(widget.earliest.year, widget.earliest.month);
    if (maximum.isBefore(minimum)) return const SizedBox.shrink();
    final value = widget.value;
    final requested = value == null
        ? null
        : DateTime.utc(value.year, value.month);
    final selected = requested == null
        ? null
        : requested.isBefore(minimum)
        ? minimum
        : requested.isAfter(maximum)
        ? maximum
        : requested;
    final selectedYear = (selected?.year ?? _year ?? maximum.year).clamp(
      minimum.year,
      maximum.year,
    );
    final firstMonth = selectedYear == minimum.year ? minimum.month : 1;
    final lastMonth = selectedYear == maximum.year ? maximum.month : 12;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BullText(widget.yearLabel, style: context.bullText.bodyMedium),
        const Gap(BullSpacing.xs),
        Semantics(
          label: widget.yearLabel,
          child: BullDropdown<int>(
            key: ValueKey('year-$selectedYear'),
            value: selectedYear,
            items: [
              for (var year = maximum.year; year >= minimum.year; year--)
                DropdownMenuItem(
                  value: year,
                  child: BullText('$year', style: context.bullText.bodyMedium),
                ),
            ],
            onChanged: (year) {
              if (year == null) return;
              final low = year == minimum.year ? minimum.month : 1;
              final high = year == maximum.year ? maximum.month : 12;
              final month = selected?.month;
              if (month == null) {
                setState(() => _year = year);
              } else {
                widget.onChanged(DateTime.utc(year, month.clamp(low, high)));
              }
            },
          ),
        ),
        const Gap(BullSpacing.md),
        BullText(widget.monthLabel, style: context.bullText.bodyMedium),
        const Gap(BullSpacing.xs),
        Semantics(
          label: widget.monthLabel,
          child: BullDropdown<int>(
            key: ValueKey('month-$selectedYear-${selected?.month}'),
            value: selected?.month,
            hint: BullText(
              widget.monthLabel,
              style: context.bullText.bodyMedium,
            ),
            items: [
              for (var month = lastMonth; month >= firstMonth; month--)
                DropdownMenuItem(
                  value: month,
                  child: BullText(
                    widget.monthName(DateTime.utc(selectedYear, month)),
                    style: context.bullText.bodyMedium,
                  ),
                ),
            ],
            onChanged: (month) {
              if (month != null) {
                widget.onChanged(DateTime.utc(selectedYear, month));
              }
            },
          ),
        ),
      ],
    );
  }
}
