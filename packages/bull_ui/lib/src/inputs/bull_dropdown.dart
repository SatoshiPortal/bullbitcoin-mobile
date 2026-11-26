import '../buttons/bull_field_action.dart';

import 'package:bull_ui/src/theme/bull_typography.dart';
import 'package:bull_ui/src/inputs/bull_dropdown_menu.dart';
import 'package:bull_ui/src/inputs/bull_picker_item.dart';
import 'package:bull_ui/src/layout/gap.dart';
import 'package:bull_ui/src/theme/bull_shapes.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// A dropdown field: a filled [BullTheme.surface] box showing the selected
/// item's label (or [hint]) with a chevron, which opens the Bull menu
/// ([showBullDropdownMenu]) as wide as the field, right under it.
///
/// Generic over the item value type [T]; an item's value may be null (a
/// placeholder row), which is why [onChanged] never fires on dismissal.
/// Takes part in an enclosing [Form]: [validator] runs on [value] and the
/// message shows under the field in [BullTheme.error].
class BullDropdown<T> extends StatelessWidget {
  const BullDropdown({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.validator,
    this.hint,
    this.trailing,
  });

  /// The choices, in menu order.
  final List<BullPickerItem<T>> items;

  /// The selected value; its item's label fills the field.
  final T? value;

  /// Fired with the picked value; null disables the field.
  final ValueChanged<T>? onChanged;

  /// Optional form validator, run on [value].
  final FormFieldValidator<T>? validator;

  /// Placeholder shown while no item matches [value].
  final String? hint;

  /// Optional detail drawn after the label, before the chevron, in the closed
  /// field only, such as the selected wallet's balance.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final shapes = context.bullShapes;
    final text = context.bullType;
    final enabled = onChanged != null;
    final selected = items.where((item) => item.value == value).firstOrNull;
    final labelColor = !enabled || selected == null
        ? colors.textMuted
        : colors.text;
    final validate = validator;
    return FormField<T>(
      initialValue: value,
      validator: validate == null ? null : (_) => validate(value),
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Builder(
            builder: (anchor) => Material(
              color: colors.surface,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(shapes.input),
                side: BorderSide(
                  color: field.hasError ? colors.error : colors.border,
                ),
              ),
              child: InkWell(
                onTap: enabled ? () => _open(anchor, field) : null,
                child: SizedBox(
                  height: 56,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: BullSpacing.md,
                      right: BullSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        if (selected?.leading case final leading?) ...[
                          leading,
                          const Gap(BullSpacing.xs),
                        ],
                        Expanded(
                          child: Text(
                            selected?.label ?? hint ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.body
                                .copyWith(fontWeight: FontWeight.w500)
                                .copyWith(color: labelColor),
                          ),
                        ),
                        if (trailing case final detail?) ...[
                          const Gap(BullSpacing.xs),
                          detail,
                          const Gap(BullSpacing.xs),
                        ],
                        ExcludeSemantics(
                          child: ExcludeFocus(
                            child: BullFieldAction(
                              label:
                                  selected?.label ??
                                  hint ??
                                  MaterialLocalizations.of(context)
                                      .moreButtonTooltip,
                              icon: Icons.expand_more,
                              onPressed: enabled
                                  ? () => _open(anchor, field)
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (field.errorText case final error?)
            Padding(
              padding: const EdgeInsets.only(
                top: BullSpacing.xxs,
                left: BullSpacing.md,
              ),
              child: Text(
                error,
                style: text.label
                    .copyWith(fontWeight: FontWeight.w400)
                    .copyWith(color: colors.error),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext anchor, FormFieldState<T> field) async {
    final index = await showBullDropdownMenu<T>(
      anchor: anchor,
      items: items,
      value: value,
      matchAnchorWidth: true,
    );
    if (index == null) return;
    final picked = items[index].value;
    if (field.mounted) field.didChange(picked);
    onChanged?.call(picked);
  }
}
