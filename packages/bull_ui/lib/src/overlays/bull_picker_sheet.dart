import 'package:material_ui/material_ui.dart';

import '../../generated/l10n/bull_ui_localizations.dart';
import '../layout/gap.dart';
import '../theme/bull_shapes.dart';
import '../theme/bull_selection_fill.dart';
import '../theme/bull_theme.dart';
import '../theme/bull_tokens.dart';
import '../theme/bull_typography.dart';

/// Generic single-selection sheet with neutral selected rows and a muted subtitle.
/// By default picking pops the route with the option; [onSelected] can map it.
class BullPickerSheet<T> extends StatelessWidget {
  const BullPickerSheet({
    super.key,
    required this.title,
    required this.options,
    required this.isSelected,
    required this.label,
    this.subtitle,
    this.isEnabled,
    this.onSelected,
  });

  final String title;
  final List<T> options;
  final bool Function(T) isSelected;
  final String Function(T) label;
  final String? Function(T)? subtitle;
  final bool Function(T)? isEnabled;
  final void Function(BuildContext, T)? onSelected;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.8,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const SizedBox(width: BullSpacing.xxl),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: context.bullType.subtitle,
                ),
              ),
            ),
            IconButton(
              tooltip: BullUiLocalizations.of(context).pickerClose,
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        Flexible(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: BullSpacing.md),
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (_, index) {
              final option = options[index];
              return BullPickerRow(
                label: label(option),
                subtitle: subtitle?.call(option),
                selected: isSelected(option),
                onPressed: isEnabled?.call(option) == false
                    ? null
                    : () {
                        final callback = onSelected;
                        if (callback != null) {
                          callback(context, option);
                        } else {
                          Navigator.pop(context, option);
                        }
                      },
              );
            },
          ),
        ),
        const Gap(BullSpacing.lg),
      ],
    ),
  );
}

/// A single exclusive choice, using the same selected fill as BullSegmented.
class BullPickerRow extends StatelessWidget {
  const BullPickerRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.subtitle,
    this.leading,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onPressed;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      enabled: onPressed != null,
      child: Material(
        color: selected ? bullSelectionFill(context) : colors.transparent,
        borderRadius: BorderRadius.circular(context.bullShapes.input),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(context.bullShapes.input),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BullSpacing.md,
                vertical: BullSpacing.sm,
              ),
              child: Row(
                children: [
                  if (leading case final widget?) ...[
                    widget,
                    const Gap(BullSpacing.sm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: context.bullType.body.copyWith(
                            color: onPressed == null
                                ? colors.textMuted
                                : selected
                                ? colors.primary
                                : colors.text,
                            fontWeight: selected
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                        ),
                        if (subtitle case final text?)
                          Text(
                            text,
                            style: context.bullType.label.copyWith(
                              color: colors.textMuted,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
