import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

class BBDropdown<T> extends StatelessWidget {
  const BBDropdown({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.validator,
    this.hint,
    this.label,
    this.height = 64,
  });

  final List<DropdownMenuItem<T>> items;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final FormFieldValidator<T>? validator;
  final Widget? hint;
  final String? label;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // height: height,
      child: Theme(
        data: Theme.of(context).copyWith(
          popupMenuTheme: PopupMenuThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4.0),
              side: BorderSide(color: context.appColors.primary, width: 1.0),
            ),
            color: context.appColors.onPrimary,
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
            dropdownColor: context.appColors.onSecondary,
            menuMaxHeight: 240,
            itemHeight: height,
            alignment: Alignment.center,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: context.appColors.surface,
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
            icon: Icon(
              Icons.keyboard_arrow_down,
              color: context.appColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}
