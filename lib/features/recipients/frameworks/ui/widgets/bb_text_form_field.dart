import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bull_ui/bull_ui.dart';

class BBTextFormField extends StatelessWidget {
  const BBTextFormField({
    super.key,
    this.labelText,
    this.labelStyle,
    this.controller,
    this.focusNode,
    this.autofocus,
    this.inputFormatters,
    this.style,
    this.textInputAction,
    this.hintText,
    this.onChanged,
    this.onFieldSubmitted,
    this.validator,
    this.prefix,
    this.prefixText,
    this.suffix,
    this.suffixText,
    this.disabled,
  });

  final String? labelText;
  final TextStyle? labelStyle;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool? autofocus;
  final List<TextInputFormatter>? inputFormatters;
  final TextStyle? style;
  final TextInputAction? textInputAction;
  final String? hintText;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final String? Function(String?)? validator;
  final String? prefixText;
  final Widget? prefix;
  final String? suffixText;
  final Widget? suffix;
  final bool? disabled;

  @override
  Widget build(BuildContext context) {
    final isDisabled = disabled ?? false;

    return FormField<String>(
      initialValue: controller?.text,
      validator: validator,
      enabled: !isDisabled,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (labelText != null)
            Text(
              labelText!,
              style:
                  labelStyle ??
                  context.font.bodyLarge?.copyWith(
                    color: isDisabled
                        ? context.appColors.outline
                        : context.appColors.secondary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          const SizedBox(height: 8),
          BullInputText(
            controller: controller,
            focusNode: focusNode,
            value: controller?.text ?? '',
            disabled: isDisabled,
            hint: hintText,
            fixedPrefix: prefixText,
            rightIcon: suffixText == null ? suffix : Text(suffixText!),
            style: style ?? context.font.bodyLarge,
            onDone: onFieldSubmitted,
            onChanged: (value) {
              var nextValue = value;
              if (inputFormatters != null) {
                final oldValue = TextEditingValue(text: controller?.text ?? '');
                var nextEditingValue = TextEditingValue(text: value);
                for (final formatter in inputFormatters!) {
                  nextEditingValue = formatter.formatEditUpdate(
                    oldValue,
                    nextEditingValue,
                  );
                }
                nextValue = nextEditingValue.text;
                if (controller != null && controller!.text != nextValue) {
                  controller!.value = nextEditingValue;
                }
              }
              field.didChange(nextValue);
              onChanged?.call(nextValue);
            },
          ),
          if (field.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                field.errorText!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: context.appColors.error),
              ),
            ),
        ],
      ),
    );
  }
}
