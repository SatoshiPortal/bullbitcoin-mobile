import 'package:bull_ui/src/inputs/bull_picker_chip.dart';
import 'package:bull_ui/src/inputs/bull_picker_item.dart';
import 'package:material_ui/material_ui.dart';

/// The app language picker, the same on every screen: each language under its
/// own name, in the order given.
class BullLanguagePicker<T> extends StatelessWidget {
  const BullLanguagePicker({
    super.key,
    required this.languages,
    required this.value,
    required this.onChanged,
    this.tooltip,
  });

  /// The languages, labelled in their own language.
  final List<BullPickerItem<T>> languages;

  /// The selected language.
  final T value;

  /// Fired with the picked language, also when it equals [value].
  final ValueChanged<T> onChanged;

  /// Accessible name of the picker.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return BullPickerChip<T>(
      items: languages,
      value: value,
      onChanged: onChanged,
      tooltip: tooltip,
    );
  }
}
