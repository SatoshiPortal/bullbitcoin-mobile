import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BBTextFormField extends StatelessWidget {
  const BBTextFormField({
    super.key,
    this.labelText,
    this.labelStyle,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.autofocus,
    this.inputFormatters,
    this.style,
    this.textInputAction,
    this.hintText,
    this.errorText,
    this.onChanged,
    this.onFieldSubmitted,
    this.validator,
    this.prefix,
    this.prefixText,
    this.suffix,
    this.suffixText,
    this.disabled,
    this.enableSuggestions = true,
    this.autocorrect = true,
    this.smartQuotesType,
    this.smartDashesType,
  });

  final String? labelText;
  final TextStyle? labelStyle;
  final TextEditingController? controller;
  final String? initialValue;
  final FocusNode? focusNode;
  final bool? autofocus;
  final List<TextInputFormatter>? inputFormatters;
  final TextStyle? style;
  final TextInputAction? textInputAction;
  final String? hintText;
  final String? errorText;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final String? Function(String?)? validator;
  final String? prefixText;
  final Widget? prefix;
  final String? suffixText;
  final Widget? suffix;
  final bool? disabled;
  final bool enableSuggestions;
  final bool autocorrect;
  final SmartQuotesType? smartQuotesType;
  final SmartDashesType? smartDashesType;

  @override
  Widget build(BuildContext context) {
    final isDisabled = disabled ?? false;

    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
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
                  fontWeight: .w500,
                ),
            textAlign: .left,
          ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          focusNode: focusNode,
          autofocus: autofocus ?? false,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          style: (style ?? context.font.bodyLarge)?.copyWith(
            color: isDisabled ? context.appColors.outline : null,
          ),
          enabled: !isDisabled,
          enableSuggestions: enableSuggestions,
          autocorrect: autocorrect,
          smartQuotesType: smartQuotesType,
          smartDashesType: smartDashesType,
          decoration: InputDecoration(
            fillColor: isDisabled
                ? context.appColors.surfaceContainerHighest
                : context.appColors.onSecondary,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide(
                color: context.appColors.secondaryFixedDim,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide(
                color: context.appColors.secondaryFixedDim,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide(
                color: context.appColors.secondaryFixedDim.withValues(
                  alpha: 0.5,
                ),
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
            hintText: hintText,
            errorText: errorText,
            hintStyle: context.font.bodyMedium?.copyWith(
              color: context.appColors.outline,
            ),
            prefixIcon: prefixText != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Text(
                      prefixText!,
                      style: (style ?? context.font.bodyLarge)?.copyWith(
                        color: isDisabled ? context.appColors.outline : null,
                      ),
                    ),
                  )
                : prefix,
            prefixIconConstraints: prefixText != null
                ? const BoxConstraints(minWidth: 0, minHeight: 0)
                : null,
            suffixIcon: suffixText != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: Text(
                      suffixText!,
                      style: (style ?? context.font.bodyLarge)?.copyWith(
                        color: isDisabled ? context.appColors.outline : null,
                      ),
                    ),
                  )
                : suffix,
            suffixIconConstraints: suffixText != null
                ? const BoxConstraints(minWidth: 0, minHeight: 0)
                : null,
          ),
          onFieldSubmitted: onFieldSubmitted,
          validator: validator,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
