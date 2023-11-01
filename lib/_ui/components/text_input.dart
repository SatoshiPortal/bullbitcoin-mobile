import 'package:bb_mobile/styles.dart';
import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';

enum _TextInputType {
  big,
  bigWithIcon,
  small,
  multiLine,
}

class BBTextInput extends StatefulWidget {
  const BBTextInput.multiLine({
    required this.onChanged,
    required this.value,
    this.rightIcon,
    this.onRightTap,
    this.disabled = false,
    this.focusNode,
    this.hint,
    this.controller,
    this.onSubmitted,
    this.textInputAction,
  })  : type = _TextInputType.multiLine,
        onEnter = null;

  const BBTextInput.big({
    required this.onChanged,
    required this.value,
    this.disabled = false,
    this.focusNode,
    this.hint,
    this.controller,
    this.onSubmitted,
    this.textInputAction,
  })  : type = _TextInputType.big,
        rightIcon = null,
        onRightTap = null,
        onEnter = null;

  const BBTextInput.bigWithIcon({
    required this.onChanged,
    required this.value,
    this.disabled = false,
    this.focusNode,
    required this.rightIcon,
    required this.onRightTap,
    this.hint,
    this.controller,
    this.onSubmitted,
    this.textInputAction,
  })  : type = _TextInputType.bigWithIcon,
        onEnter = null;

  const BBTextInput.small({
    required this.onChanged,
    required this.value,
    this.disabled = false,
    this.focusNode,
    this.hint,
    this.controller,
    this.onEnter,
    this.onSubmitted,
    this.textInputAction,
  })  : type = _TextInputType.small,
        rightIcon = null,
        onRightTap = null;

  final _TextInputType type;

  final TextEditingController? controller;
  final Function(String) onChanged;
  final String value;
  final String? hint;
  final Widget? rightIcon;
  final Function? onRightTap;
  final bool disabled;
  final FocusNode? focusNode;
  final Function? onEnter;
  final Function(String)? onSubmitted;
  final TextInputAction? textInputAction;

  @override
  State<BBTextInput> createState() => _BBTextInputState();
}

class _BBTextInputState extends State<BBTextInput> {
  final _editingController = TextEditingController();

  @override
  void dispose() {
    _editingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.value != _editingController.text) _editingController.text = widget.value;

    Widget widgett;

    switch (widget.type) {
      case _TextInputType.multiLine:
        widgett = TextField(
          focusNode: widget.focusNode,
          enabled: !widget.disabled,
          onChanged: widget.onChanged,
          controller: _editingController,
          enableIMEPersonalizedLearning: false,
          keyboardType: TextInputType.multiline,
          maxLines: 5,
          style: context.font.bodySmall!.copyWith(color: context.colour.onBackground),
          decoration: InputDecoration(
            suffixIcon: widget.rightIcon,
            hintText: widget.hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24.0),
              borderSide: BorderSide(
                color: context.colour.onBackground.withOpacity(0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24.0),
              borderSide: BorderSide(
                color: context.colour.onBackground,
              ),
            ),
          ),
        );

      case _TextInputType.big:
        widgett = TextField(
          enabled: !widget.disabled,
          focusNode: widget.focusNode,
          onChanged: widget.onChanged,
          enableIMEPersonalizedLearning: false,
          controller: _editingController,
          decoration: InputDecoration(
            hintText: widget.hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(80.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(80.0),
              borderSide: BorderSide(
                color: context.colour.onBackground.withOpacity(0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(80.0),
              borderSide: BorderSide(
                color: context.colour.onBackground,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(80.0),
              borderSide: BorderSide(
                color: context.colour.onBackground.withOpacity(0.2),
              ),
            ),
            labelStyle: context.font.labelSmall,
            contentPadding: const EdgeInsets.only(bottom: 8, left: 24),
          ),
        );
      case _TextInputType.bigWithIcon:
        widgett = TextField(
          focusNode: widget.focusNode,
          enabled: !widget.disabled,
          onChanged: widget.onChanged,
          controller: _editingController,
          enableIMEPersonalizedLearning: false,
          decoration: InputDecoration(
            hintText: widget.hint,
            suffixIcon: IconButton(
              icon: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: widget.rightIcon,
              ),
              onPressed: () => widget.onRightTap!(),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(80.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(80.0),
              borderSide: BorderSide(
                color: context.colour.onBackground.withOpacity(0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(80.0),
              borderSide: BorderSide(
                color: context.colour.onBackground,
              ),
            ),
            labelStyle: context.font.labelSmall,
            contentPadding: const EdgeInsets.only(bottom: 8, left: 24),
          ),
        );
      case _TextInputType.small:
        widgett = SizedBox(
          height: 40,
          child: TextField(
            focusNode: widget.focusNode,
            enabled: !widget.disabled,
            onChanged: widget.onChanged,
            onSubmitted: (value) => widget.onSubmitted?.call(value),
            controller: _editingController,
            onTap: () => widget.onEnter!(),
            enableIMEPersonalizedLearning: false,
            textInputAction: widget.textInputAction,
            decoration: InputDecoration(
              hintText: widget.hint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(80.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(80.0),
                borderSide: BorderSide(
                  color: context.colour.onBackground.withOpacity(0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(80.0),
                borderSide: BorderSide(
                  color: context.colour.onBackground,
                ),
              ),
              labelStyle: context.font.labelSmall,
              contentPadding: const EdgeInsets.only(bottom: 8, left: 24),
            ),
          ),
        );
    }

    return widgett;
  }
}

class BBAmountInput extends StatefulWidget {
  const BBAmountInput({
    super.key,
    required this.onChanged,
    this.value,
    required this.hint,
    required this.onRightTap,
    required this.disabled,
    required this.btcFormatting,
    required this.isSats,
  });

  final Function(String) onChanged;
  final String? value;
  final String hint;
  final bool btcFormatting;
  final bool isSats;

  final Function onRightTap;
  final bool disabled;

  @override
  State<BBAmountInput> createState() => _BBAmountInputState();
}

class _BBAmountInputState extends State<BBAmountInput> {
  final _editingController = TextEditingController();

  @override
  void dispose() {
    _editingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.value != null && _editingController.text != widget.value)
      _editingController.text = widget.value!;

    return TextField(
      enabled: !widget.disabled,
      onChanged: widget.onChanged,
      controller: _editingController,
      enableIMEPersonalizedLearning: false,
      keyboardType: TextInputType.number,
      inputFormatters: [
        // if (widget.btcFormatting)
        //   CurrencyTextInputFormatter(
        //     decimalDigits: 8,
        //     enableNegative: false,
        //     symbol: '',
        //   )
        // else
        if (widget.isSats)
          CurrencyTextInputFormatter(
            decimalDigits: 0,
            enableNegative: false,
            symbol: '',
          ),
        // else
        //   CurrencyTextInputFormatter(
        //     decimalDigits: 2,
        //     enableNegative: false,
        //     symbol: '',
        //   ),
      ],
      decoration: InputDecoration(
        hintText: widget.hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(80.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(80.0),
          borderSide: BorderSide(
            color: context.colour.onBackground.withOpacity(0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(80.0),
          borderSide: BorderSide(
            color: context.colour.onBackground,
          ),
        ),
        contentPadding: const EdgeInsets.only(bottom: 8, left: 24),
      ),
    );
  }
}
