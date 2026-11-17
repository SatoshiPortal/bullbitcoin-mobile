import 'package:material_ui/material_ui.dart';

/// One choice of a `BullDropdown`, `BullPickerMenu` or `BullPickerChip`.
class BullPickerItem<T> {
  const BullPickerItem({
    required this.value,
    required this.label,
    this.leading,
  });

  /// The value reported to `onChanged`.
  final T value;

  /// The text shown in the menu, and in the field or chip once selected.
  final String label;

  /// Optional widget drawn before [label], in the menu and in the closed field.
  final Widget? leading;
}
