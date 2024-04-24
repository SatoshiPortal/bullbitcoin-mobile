import 'package:bb_mobile/styles.dart';
import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';

enum _TextInputType {
  big,
  bigWithIcon,
  bigWithIcon2,

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
    this.uiKey,
  })  : type = _TextInputType.multiLine,
        onEnter = null,
        onDone = null,
        maxLength = null,
        onlyNumbers = false;

  const BBTextInput.big({
    required this.onChanged,
    required this.value,
    this.disabled = false,
    this.onlyNumbers = false,
    this.focusNode,
    this.hint,
    this.controller,
    this.maxLength,
    this.uiKey,
    this.onEnter,
  })  : type = _TextInputType.big,
        rightIcon = null,
        onRightTap = null,
        onDone = null;

  const BBTextInput.bigWithIcon({
    required this.onChanged,
    required this.value,
    this.onlyNumbers = false,
    this.disabled = false,
    this.focusNode,
    required this.rightIcon,
    required this.onRightTap,
    this.hint,
    this.uiKey,
    this.controller,
  })  : type = _TextInputType.bigWithIcon,
        onEnter = null,
        onDone = null,
        maxLength = null;

  const BBTextInput.bigWithIcon2({
    required this.onChanged,
    required this.value,
    this.onlyNumbers = false,
    this.disabled = false,
    this.focusNode,
    required this.rightIcon,
    // required this.onRightTap,
    this.hint,
    this.uiKey,
    this.controller,
  })  : type = _TextInputType.bigWithIcon2,
        onEnter = null,
        onDone = null,
        onRightTap = null,
        maxLength = null;

  const BBTextInput.small({
    required this.onChanged,
    required this.value,
    this.uiKey,
    this.onlyNumbers = false,
    this.disabled = false,
    this.focusNode,
    this.hint,
    this.controller,
    this.onEnter,
    this.onDone,
  })  : type = _TextInputType.small,
        rightIcon = null,
        onRightTap = null,
        maxLength = null;

  final _TextInputType type;

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

  static double height = 60;

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
          onTap: () => widget.onEnter?.call(),
          decoration: InputDecoration(
            suffixIcon: widget.rightIcon,
            hintText: widget.hint,
            // suffix: widget.rightIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide(
                color: context.colour.onBackground.withOpacity(0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide(
                color: context.colour.onBackground,
              ),
            ),
          ),
        );

      case _TextInputType.big:
        widgett = SizedBox(
          height: height,
          child: TextField(
            expands: true,
            maxLines: null,
            key: widget.uiKey,
            enabled: !widget.disabled,
            focusNode: widget.focusNode,
            onChanged: widget.onChanged,
            maxLength: widget.maxLength,
            enableIMEPersonalizedLearning: false,
            controller: _editingController,
            keyboardType: widget.onlyNumbers ? TextInputType.number : null,
            onTap: () => widget.onEnter?.call(),
            decoration: InputDecoration(
              hintText: widget.hint,
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(
                  color: context.colour.onBackground.withOpacity(0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(
                  color: context.colour.onBackground,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(
                  color: context.colour.onBackground.withOpacity(0.2),
                ),
              ),
              labelStyle: context.font.labelSmall,
              contentPadding: const EdgeInsets.only(bottom: 8, left: 24),
            ),
          ),
        );
      case _TextInputType.bigWithIcon:
        widgett = SizedBox(
          height: height,
          child: TextField(
            expands: true,
            maxLines: null,
            focusNode: widget.focusNode,
            enabled: !widget.disabled,
            onChanged: widget.onChanged,
            controller: _editingController,
            enableIMEPersonalizedLearning: false,
            keyboardType: widget.onlyNumbers ? TextInputType.number : null,
            onTap: () => widget.onEnter?.call(),
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
                borderRadius: BorderRadius.circular(8.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(
                  color: context.colour.onBackground.withOpacity(0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(
                  color: context.colour.onBackground,
                ),
              ),
              labelStyle: context.font.labelSmall,
              contentPadding: const EdgeInsets.only(bottom: 8, left: 24),
            ),
          ),
        );
      case _TextInputType.bigWithIcon2:
        widgett = SizedBox(
          height: height,
          child: TextField(
            expands: true,
            maxLines: null,
            focusNode: widget.focusNode,
            enabled: !widget.disabled,
            onChanged: widget.onChanged,
            controller: _editingController,
            enableIMEPersonalizedLearning: false,
            onTap: () => widget.onEnter?.call(),
            keyboardType: widget.onlyNumbers ? TextInputType.number : null,
            decoration: InputDecoration(
              hintText: widget.hint,
              suffixIcon: widget.rightIcon,
              // IconButton(
              //   icon: Padding(
              //     padding: const EdgeInsets.only(right: 16),
              //     child: widget.rightIcon,
              //   ),
              //   onPressed: () => widget.onRightTap!(),
              // ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(
                  color: context.colour.onBackground.withOpacity(0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(
                  color: context.colour.onBackground,
                ),
              ),
              labelStyle: context.font.labelSmall,
              contentPadding: const EdgeInsets.only(bottom: 8, left: 24),
            ),
          ),
        );
      case _TextInputType.small:
        widgett = SizedBox(
          height: 40,
          child: TextField(
            key: widget.uiKey,
            focusNode: widget.focusNode,
            enabled: !widget.disabled,
            onChanged: widget.onChanged,
            controller: _editingController,
            keyboardType: widget.onlyNumbers ? TextInputType.number : null,

            onSubmitted: (value) => widget.onDone?.call(value),
            // widget.onDone != null ? widget.onDone!(value) : null,
            onTap: () => widget.onEnter?.call(),
            enableIMEPersonalizedLearning: false,
            decoration: InputDecoration(
              hintText: widget.hint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(
                  color: context.colour.onBackground.withOpacity(0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
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

// class BBAmountInput extends StatefulWidget {
//   const BBAmountInput({
//     required this.onChanged,
//     this.value,
//     required this.hint,
//     // this.onRightTap,
//     required this.disabled,
//     required this.btcFormatting,
//     required this.isSats,
//     this.selected = false,
//     this.focusNode,
//     this.uiKey,
//   });

//   final Function(String) onChanged;
//   final String? value;
//   final String hint;
//   final bool btcFormatting;
//   final bool isSats;
//   final bool selected;

//   // final Function? onRightTap;
//   final bool disabled;
//   final FocusNode? focusNode;
//   final Key? uiKey;

//   @override
//   State<BBAmountInput> createState() => _BBAmountInputState();
// }

// class _BBAmountInputState extends State<BBAmountInput> {
//   final _editingController = TextEditingController();

//   @override
//   void dispose() {
//     _editingController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (widget.value != null && _editingController.text != widget.value)
//       _editingController.text = widget.value!;

//     final borderColor =
//         widget.selected ? context.colour.primary : context.colour.onBackground.withOpacity(0.2);

//     return TextField(
//       key: widget.uiKey,
//       enabled: !widget.disabled,
//       onChanged: widget.onChanged,
//       controller: _editingController,
//       enableIMEPersonalizedLearning: false,
//       keyboardType: TextInputType.number,
//       focusNode: widget.focusNode,
//       scrollPadding: const EdgeInsets.only(bottom: 100),
//       inputFormatters: [
//         // if (widget.btcFormatting)
//         //   CurrencyTextInputFormatter(
//         //     decimalDigits: 8,
//         //     enableNegative: false,
//         //     symbol: '',
//         //   )
//         // else
//         if (widget.isSats)
//           CurrencyTextInputFormatter(
//             decimalDigits: 0,
//             enableNegative: false,
//             symbol: '',
//           ),
//         // else
//         //   CurrencyTextInputFormatter(
//         //     decimalDigits: 2,
//         //     enableNegative: false,
//         //     symbol: '',
//         //   ),
//       ],
//       decoration: InputDecoration(
//         hintText: widget.hint,
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(8.0),
//           borderSide: BorderSide(color: borderColor),
//         ),
//         enabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(8.0),
//           borderSide: BorderSide(color: borderColor),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(8.0),
//           borderSide: BorderSide(color: borderColor),
//         ),
//         contentPadding: const EdgeInsets.only(bottom: 8, left: 24),
//         // scrollPadding: EdgeInsets.only(bottom:40),
//       ),
//     );
//   }
// }

class BBAmountInput extends StatefulWidget {
  const BBAmountInput({
    required this.onChanged,
    this.value,
    required this.hint,
    // this.onRightTap,
    required this.disabled,
    required this.btcFormatting,
    required this.isSats,
    this.selected = false,
    this.focusNode,
    this.uiKey,
  });

  final Function(String) onChanged;
  final String? value;
  final String hint;
  final bool btcFormatting;
  final bool isSats;
  final bool selected;

  // final Function? onRightTap;
  final bool disabled;
  final FocusNode? focusNode;
  final Key? uiKey;

  @override
  State<BBAmountInput> createState() => _BBAmountInputState2();
}

class _BBAmountInputState2 extends State<BBAmountInput> {
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

    final borderColor =
        widget.selected ? context.colour.primary : context.colour.onBackground.withOpacity(0.2);

    return SizedBox(
      height: 60,
      child: TextField(
        expands: true,
        maxLines: null,
        key: widget.uiKey,
        enabled: !widget.disabled,
        onChanged: widget.onChanged,
        controller: _editingController,
        enableIMEPersonalizedLearning: false,
        keyboardType: TextInputType.number,
        focusNode: widget.focusNode,
        scrollPadding: const EdgeInsets.only(bottom: 100),
        inputFormatters: [
          // if (widget.btcFormatting)
          //   CurrencyTextInputFormatter(
          //     decimalDigits: 8,
          //     enableNegative: false,
          //     symbol: '',
          //   )
          // else
          if (widget.isSats)
            CurrencyTextInputFormatter.currency(
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
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: borderColor),
          ),
          contentPadding: const EdgeInsets.only(bottom: 8, left: 24),
          // scrollPadding: EdgeInsets.only(bottom:40),
        ),
      ),
    );
  }
}
