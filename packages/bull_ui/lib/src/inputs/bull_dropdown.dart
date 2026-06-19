import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:flutter/material.dart';

/// A themed [DropdownButtonFormField] — duplicated from
/// `core/widgets/dropdown/bb_dropdown.dart` (`BBDropdown`).
///
/// Generic over the item value type [T]. Items are left-aligned and the menu
/// is capped at 240px tall.
class BullDropdown<T> extends StatelessWidget {
  const BullDropdown({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.validator,
    this.hint,
    this.label,
    this.height = 64,
  });

  /// The selectable items.
  final List<DropdownMenuItem<T>> items;

  /// The currently selected value.
  final T? value;

  /// Fired on selection; null disables the dropdown.
  final ValueChanged<T?>? onChanged;

  /// Optional form validator.
  final FormFieldValidator<T>? validator;

  /// Placeholder widget shown when nothing is selected.
  final Widget? hint;

  /// Optional label (currently unused by the layout; kept for API parity).
  final String? label;

  /// Per-item height.
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return SizedBox(
      child: Theme(
        data: Theme.of(context).copyWith(
          popupMenuTheme: PopupMenuThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4.0),
              side: BorderSide(color: colors.primary, width: 1.0),
            ),
            color: colors.onPrimary,
            elevation: 8,
          ),
        ),
        child: ButtonTheme(
          alignedDropdown: true,
          child: DropdownButtonFormField<T>(
            initialValue: value,
            items: items.map((item) {
              return DropdownMenuItem<T>(
                value: item.value,
                child: Container(
                  width: double.infinity,
                  alignment: Alignment.centerLeft,
                  child: item.child,
                ),
              );
            }).toList(),
            onChanged: onChanged,
            validator: validator,
            hint: hint,
            dropdownColor: colors.onSecondary,
            menuMaxHeight: 240,
            itemHeight: height,
            alignment: Alignment.center,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: colors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4.0),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 16.0,
              ),
              isDense: false,
            ),
            icon: Icon(Icons.keyboard_arrow_down, color: colors.primary),
          ),
        ),
      ),
    );
  }
}
