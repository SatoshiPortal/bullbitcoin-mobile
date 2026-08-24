import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The standard themed text field — duplicated from
/// `core/widgets/inputs/text_input.dart` (`BBInputText`).
///
/// Supports a fixed prefix, trailing icon, obscuring, numeric/paste-only
/// keyboards, length limits and single/multi-line layouts. Keeps the original
/// controlled-value behaviour (the parent owns [value]).
class BullInputText extends StatefulWidget {
  const BullInputText({
    super.key,
    this.uiKey,
    this.controller,
    required this.onChanged,
    required this.value,
    this.hint,
    this.hintStyle,
    this.rightIcon,
    this.onRightTap,
    this.disabled = false,
    this.focusNode,
    this.onEnter,
    this.onDone,
    this.maxLength,
    this.onlyPaste = false,
    this.onlyNumbers = false,
    this.obscure = false,
    this.enableSuggestions = true,
    this.autocorrect = true,
    this.smartQuotesType,
    this.smartDashesType,
    this.style,
    this.hideBorder = false,
    this.maxLines,
    this.minLines,
    this.fixedPrefix,
  });

  /// Key applied to the inner [TextField] (for widget tests).
  final Key? uiKey;

  /// Optional external controller; one is created if null.
  final TextEditingController? controller;

  /// Fired on every change.
  final Function(String) onChanged;

  /// The current value (the field is controlled by the parent).
  final String value;

  /// Placeholder text.
  final String? hint;

  /// Placeholder style override.
  final TextStyle? hintStyle;

  /// Trailing icon widget.
  final Widget? rightIcon;

  /// Tap callback for [rightIcon].
  final Function? onRightTap;

  /// Disables input when true.
  final bool disabled;

  /// External focus node.
  final FocusNode? focusNode;

  /// Called when the field is tapped/focused.
  final Function? onEnter;

  /// Called on submit.
  final Function(String)? onDone;

  /// Maximum input length.
  final int? maxLength;

  /// When true, blocks the soft keyboard (paste only).
  final bool onlyPaste;

  /// When true, shows a decimal numeric keyboard.
  final bool onlyNumbers;

  /// Obscures the text (e.g. for secrets).
  final bool obscure;

  /// Both default to true. Set them false for secrets (a BIP39 passphrase):
  /// the IME's suggestion and autocorrect caches must never see the value.
  final bool enableSuggestions;
  final bool autocorrect;

  /// iOS Smart Punctuation, which rewrites `'` as `’` and `--` as `—`.
  /// Left null, [TextField] enables it (unless [obscure]). Disable both when
  /// the value must survive exactly as typed.
  final SmartQuotesType? smartQuotesType;
  final SmartDashesType? smartDashesType;

  /// Maximum lines.
  final int? maxLines;

  /// Minimum lines.
  final int? minLines;

  /// Text style override.
  final TextStyle? style;

  /// Hides the border when true.
  final bool hideBorder;

  /// A fixed, non-editable prefix shown inside the field.
  final String? fixedPrefix;

  @override
  State<BullInputText> createState() => _BullInputTextState();
}

class _BullInputTextState extends State<BullInputText> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ?? TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(BullInputText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  InputBorder _getBorder(BuildContext context) {
    if (widget.hideBorder) return InputBorder.none;

    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(BullRadius.xs),
      borderSide: BorderSide(color: context.bull.border),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    // Numeric and obscured fields are never legitimately multiline, so they
    // default to a single line instead of Flutter's unlimited `null`.
    final effectiveMaxLines =
        widget.maxLines ?? (widget.obscure || widget.onlyNumbers ? 1 : null);
    final shouldPreventNewlines =
        effectiveMaxLines != null && effectiveMaxLines <= 2;

    return TextField(
      key: widget.uiKey,
      controller: _controller,
      onChanged: widget.onChanged,
      focusNode: widget.focusNode,
      enabled: !widget.disabled,
      keyboardType: widget.onlyPaste
          ? TextInputType.none
          : widget.onlyNumbers
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.multiline,
      textInputAction: shouldPreventNewlines
          ? TextInputAction.done
          : TextInputAction.newline,
      inputFormatters: [
        if (shouldPreventNewlines)
          FilteringTextInputFormatter.deny(RegExp(r'\n')),
        if (widget.maxLength != null)
          LengthLimitingTextInputFormatter(widget.maxLength),
      ],
      obscureText: widget.obscure,
      obscuringCharacter: widget.onlyNumbers ? 'x' : '*',
      enableIMEPersonalizedLearning: false,
      enableSuggestions: widget.enableSuggestions,
      autocorrect: widget.autocorrect,
      smartQuotesType: widget.smartQuotesType,
      smartDashesType: widget.smartDashesType,
      maxLength: widget.maxLength,
      minLines: widget.minLines ?? 1,
      maxLines: effectiveMaxLines,
      style:
          widget.style ??
          Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w400,
            color: colors.onSurface,
          ),
      onTap: () => widget.onEnter?.call(),
      onSubmitted: widget.onDone,
      textAlign: TextAlign.left,
      textAlignVertical: TextAlignVertical.center,
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: widget.hintStyle ?? TextStyle(color: colors.textMuted),
        prefixIcon: widget.fixedPrefix != null
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                child: Text(
                  widget.fixedPrefix!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            : null,
        suffixIcon: widget.rightIcon != null
            ? IconButton(
                padding: const EdgeInsets.all(4),
                icon: widget.rightIcon!,
                onPressed: () => widget.onRightTap?.call(),
              )
            : null,
        border: _getBorder(context),
        enabledBorder: _getBorder(context),
        focusedBorder: _getBorder(context),
        disabledBorder: _getBorder(context),
        contentPadding: const EdgeInsets.all(16),
        filled: true,
        fillColor: colors.surface,
      ),
    );
  }
}
