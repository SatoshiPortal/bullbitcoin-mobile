import 'package:bb_mobile/_ui/components/text/text.dart';
import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

class ObscuredTextInput extends StatefulWidget {
  const ObscuredTextInput({
    super.key,
    required this.text,
    this.obscure = true,
    required this.onVisibilityToggle,
    this.isPassword = false,
    this.onChanged,
  });

  final String text;
  final bool obscure;
  final void Function() onVisibilityToggle;
  final bool isPassword;
  final void Function(String)? onChanged;

  @override
  State<ObscuredTextInput> createState() => _ObscuredTextInputState();
}

class _ObscuredTextInputState extends State<ObscuredTextInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.text);
  }

  @override
  void didUpdateWidget(ObscuredTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != _controller.text) {
      _controller.text = widget.text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: context.colour.onPrimary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.colour.secondaryFixedDim,
        ),
      ),
      child: Row(
        children: [
          const Gap(15),
          Expanded(
            child: TextFormField(
              controller: _controller,
              keyboardAppearance: context.theme.brightness,
              onChanged: widget.onChanged,
              obscureText: widget.obscure,
              keyboardType:
                  widget.isPassword ? TextInputType.visiblePassword : null,
              style: context.font.bodyLarge?.copyWith(
                color: context.colour.secondary,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              readOnly: !widget.isPassword, // Only readonly for PIN mode
              showCursor: true,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            icon: Icon(
              widget.obscure ? Icons.visibility : Icons.visibility_off,
              color: context.colour.secondary,
            ),
            onPressed: widget.onVisibilityToggle,
          ),
          const Gap(8),
        ],
      ),
    );
  }
}
