import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';

class BBInputText extends StatefulWidget {
  final Key? uiKey;

  final TextEditingController? controller;
  final Function(String) onChanged;

  final String value;
  final String? hint;
  final Widget? rightIcon;
  final Function? onRightTap;
  final bool disabled;
  final FocusNode? focusNode;
  final Function? onEnter;
  final Function(String)? onDone;
  final int? maxLength;
  final bool onlyNumbers;
  final bool? obscure;
  final TextStyle? style;
  final bool hideBorder;
  const BBInputText({
    this.uiKey,
    this.controller,
    required this.onChanged,
    required this.value,
    this.hint,
    this.rightIcon,
    this.onRightTap,
    this.disabled = false,
    this.focusNode,
    this.onEnter,
    this.onDone,
    this.maxLength,
    this.onlyNumbers = false,
    this.obscure = false,
    this.style,
    this.hideBorder = false,
  });

  @override
  State<BBInputText> createState() => _BBInputTextState();
}

class _BBInputTextState extends State<BBInputText> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ?? TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(BBInputText oldWidget) {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: context.colour.onPrimary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colour.secondaryFixedDim),
      ),
      child: TextField(
        expands: !(widget.obscure ?? false),
        maxLines: widget.obscure ?? false ? 1 : null,
        focusNode: widget.focusNode,
        enabled: !widget.disabled,
        onChanged: widget.onChanged,
        controller: _controller,
        enableIMEPersonalizedLearning: false,
        keyboardType: widget.onlyNumbers ? null : TextInputType.text,
        obscureText: widget.obscure ?? false,
        obscuringCharacter: widget.onlyNumbers ? 'x' : '*',
        onTap: () => widget.onEnter?.call(),
        style:
            widget.style ??
            context.font.headlineSmall?.copyWith(
              color: context.colour.secondary,
            ),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(
            color: context.colour.onPrimaryContainer.withValues(alpha: 0.5),
          ),
          suffixIcon:
              widget.rightIcon != null
                  ? IconButton(
                    padding: const EdgeInsets.all(5),
                    icon: widget.rightIcon!,
                    onPressed: () => widget.onRightTap!(),
                  )
                  : null,
          border: InputBorder.none,
          labelStyle: context.font.labelSmall,
          contentPadding: const EdgeInsets.all(16),
        ),
        maxLength: widget.maxLength,
      ),
    );
  }
}
