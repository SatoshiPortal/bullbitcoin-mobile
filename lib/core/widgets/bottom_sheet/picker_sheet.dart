import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Generic single-selection bottom-sheet picker.
///
/// Mirrors the structure of [CurrencyBottomSheet] (rounded-top surface,
/// centered title, close icon, scrollable list of `InkWell` rows) so that
/// theme/language/etc. pickers across the app share the same UX.
///
/// Pop with the picked value via `Navigator.pop(context, option)` — this
/// widget does not call `showModalBottomSheet` itself; pass it as the
/// `child` of [BlurredBottomSheet.show].
class BBPickerSheet<T> extends StatelessWidget {
  const BBPickerSheet({
    super.key,
    required this.title,
    required this.options,
    required this.isSelected,
    required this.label,
  });

  final String title;
  final List<T> options;
  final bool Function(T) isSelected;
  final String Function(T) label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
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
                style: context.font.headlineMedium?.copyWith(
                  color: context.appColors.onSurface,
                ),
              ),
              const Spacer(),
              IconButton(
                iconSize: 20,
                onPressed: () => Navigator.pop(context),
                color: context.appColors.onSurface,
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
                            style: context.font.headlineSmall?.copyWith(
                              color: selected
                                  ? context.appColors.primary
                                  : context.appColors.onSurface,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (selected)
                          Icon(Icons.check, color: context.appColors.primary),
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
