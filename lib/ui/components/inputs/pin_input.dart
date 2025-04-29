import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';

class PinInput extends StatelessWidget {
  final String value;
  final bool obscure;
  final Function()? onRightTap;
  final Widget? rightIcon;
  final Function(String)? onChanged;

  const PinInput({
    super.key,
    required this.value,
    this.obscure = true,
    this.onRightTap,
    this.rightIcon,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: context.colour.outline,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        readOnly: true,
        obscureText: obscure,
        controller: TextEditingController(text: value),
        onChanged: onChanged,
        style: context.font.bodyLarge,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          border: InputBorder.none,
          suffixIcon: rightIcon != null
              ? GestureDetector(
                  onTap: onRightTap,
                  child: rightIcon,
                )
              : null,
        ),
      ),
    );
  }
}
