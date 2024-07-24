import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class BBFormField extends StatelessWidget {
  const BBFormField({
    super.key,
    required this.editingController,
    this.label = '',
    this.placeholderText,
    this.suffix,
    this.keyboardType,
    this.disabled = false,
    this.centered = false,
    this.selected = false,
    this.errorMsg = '',
    this.decoration,
    this.bottomPadding = 10.0,
  });

  final TextEditingController editingController;
  final String label;
  final String? placeholderText;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final bool disabled;
  final bool centered;
  final bool selected;
  final String errorMsg;
  final InputDecoration? decoration;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? context.colour.primary
        : context.colour.onPrimaryContainer.withOpacity(0.2);

    // TODO: Ideally move this to theme file
    final InputDecoration decoration = InputDecoration(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: borderColor),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: borderColor),
      ),
      contentPadding: const EdgeInsets.only(bottom: 8, left: 16),
      error: errorMsg.isNotEmpty
          ? Text(
              errorMsg,
              style: const TextStyle(color: Colors.red),
            )
          : null,
      suffixIcon: suffix,
      hintText: placeholderText,
      // scrollPadding: EdgeInsets.only(bottom:40),
    );

    return Column(
      crossAxisAlignment: centered == true
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) Text(label),
        const SizedBox(
          height: 10,
        ),
        TextFormField(
          controller: editingController,
          keyboardType: keyboardType,
          enabled: !disabled,
          decoration: decoration,
        ),
        Gap(bottomPadding),
      ],
    );
  }
}
