import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pattern_formatter/numeric_formatter.dart';

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
  }) : type = _TextInputType.multiLine;

  const BBTextInput.big({
    required this.onChanged,
    required this.value,
    this.disabled = false,
    this.focusNode,
    this.hint,
    this.controller,
  })  : type = _TextInputType.big,
        rightIcon = null,
        onRightTap = null;

  const BBTextInput.bigWithIcon({
    required this.onChanged,
    required this.value,
    this.disabled = false,
    this.focusNode,
    required this.rightIcon,
    required this.onRightTap,
    this.hint,
    this.controller,
  }) : type = _TextInputType.bigWithIcon;

  const BBTextInput.small({
    required this.onChanged,
    required this.value,
    this.disabled = false,
    this.focusNode,
    this.hint,
    this.controller,
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
            controller: _editingController,
            enableIMEPersonalizedLearning: false,
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
    required this.value,
    required this.hint,
    required this.onRightTap,
    required this.disabled,
    required this.isSats,
  });

  final Function(String) onChanged;
  final String value;
  final String hint;
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
    if (_editingController.text != widget.value) {
      _editingController.text = widget.value;

      if (widget.isSats)
        _editingController.selection = TextSelection.fromPosition(
          TextPosition(
            offset: widget.value.length,
          ),
        );
      else
        _editingController.selection = TextSelection.fromPosition(
          TextPosition(
            offset: _editingController.text.length,
          ),
        );
    }

    return TextField(
      enabled: !widget.disabled,
      onChanged: widget.onChanged,
      controller: _editingController,
      enableIMEPersonalizedLearning: false,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
      ),
      inputFormatters: [
        if (!widget.isSats)
          ThousandsFormatter(
            formatter: NumberFormat()
              ..maximumFractionDigits = 8
              ..minimumFractionDigits = 8
              ..minimumExponentDigits = 1
              ..turnOffGrouping(),
            allowFraction: true,
          )
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
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: widget.isSats
              ? IconButton(
                  color: context.colour.secondary,
                  onPressed: () {
                    widget.onRightTap();
                  },
                  icon: const FaIcon(
                    FontAwesomeIcons.coins,
                  ),
                )
              : IconButton(
                  color: context.colour.secondary,
                  onPressed: () {
                    widget.onRightTap();
                  },
                  icon: const FaIcon(
                    FontAwesomeIcons.bitcoin,
                  ),
                ),
        ),
      ),
    );
  }
}
