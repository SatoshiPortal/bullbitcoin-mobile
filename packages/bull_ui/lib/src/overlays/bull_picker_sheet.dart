import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Generic single-selection bottom-sheet picker — duplicated from
/// `core/widgets/bottom_sheet/picker_sheet.dart` (`BBPickerSheet`).
///
/// Rounded-top surface with a centered title, close icon and a scrollable list
/// of tappable rows; the selected row is tinted [BullTheme.red] and shows a
/// check. Pop with the picked value via `Navigator.pop(context, option)` — this
/// widget does not call `showModalBottomSheet` itself; pass it as the `child`
/// of [BullBottomSheet.show].
class BullPickerSheet<T> extends StatelessWidget {
  const BullPickerSheet({
    super.key,
    required this.title,
    required this.options,
    required this.isSelected,
    required this.label,
  });

  /// Sheet header title.
  final String title;

  /// The selectable options.
  final List<T> options;

  /// Whether a given option is the currently selected one.
  final bool Function(T) isSelected;

  /// Human-readable label for a given option.
  final String Function(T) label;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Gap(16),
          Row(
            children: [
              const Gap(48),
              const Spacer(),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: colors.onSurface),
              ),
              const Spacer(),
              IconButton(
                iconSize: 20,
                onPressed: () => Navigator.pop(context),
                color: colors.onSurface,
                icon: const Icon(Icons.close),
              ),
              const Gap(16),
            ],
          ),
          const Gap(16),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (_, i) {
                final option = options[i];
                final selected = isSelected(option);
                return InkWell(
                  onTap: () => Navigator.pop(context, option),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 40,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            label(option),
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: selected ? colors.primary : colors.onSurface,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (selected) Icon(Icons.check, color: colors.primary),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Gap(24),
        ],
      ),
    );
  }
}
