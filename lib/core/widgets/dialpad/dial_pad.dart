import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';

enum DialPadMode { int, double, pin }

class DialPad extends StatefulWidget {
  const DialPad({
    super.key,
    required this.onChanged,
    this.disableFeedback = false,
    required this.mode,
  });

  final Function(String) onChanged;
  final bool disableFeedback;
  final DialPadMode mode;

  @override
  State<DialPad> createState() => _DialPadState();
}

class _DialPadState extends State<DialPad> {
  late final TextEditingController controller;
  bool get hasDot => controller.text.contains('.');

  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void onTextChanged(String num) {
    final text = controller.text;

    switch (widget.mode) {
      case DialPadMode.int:
        final intValue = int.tryParse(text + num);
        if (intValue == null) break;
        controller.text = text + num;
      case DialPadMode.double:
        if (hasDot && num == '.') break;
        if (!hasDot && num == '.') {
          controller.text = text + num;
          break;
        }
        if (!hasDot && num != '.') {
          final intValue = int.tryParse(text + num);
          if (intValue == null) break;
          controller.text = intValue.toString();
          break;
        }
        if (hasDot) {
          final doubleValue = double.tryParse(text + num);
          if (doubleValue == null) break;
          controller.text = doubleValue.toString();
          break;
        }
      case DialPadMode.pin:
        controller.text += num;
    }

    widget.onChanged(controller.text);
  }

  void onBackspacePressed() {
    if (controller.text.isEmpty) return;
    controller.text = controller.text.substring(0, controller.text.length - 1);

    widget.onChanged(controller.text);
  }

  Widget numPadButton(BuildContext context, String num) {
    return Expanded(
      child: InkWell(
        onTap: () => onTextChanged(num),
        splashFactory: widget.disableFeedback ? NoSplash.splashFactory : null,
        highlightColor: widget.disableFeedback ? Colors.transparent : null,
        child: SizedBox(
          height: 64,
          child: Center(
            child: BBText(
              num,
              style: context.font.headlineMedium?.copyWith(fontSize: 20),
              color: context.colour.surfaceContainerLow,
            ),
          ),
        ),
      ),
    );
  }

  Widget backspaceButton(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: () => onBackspacePressed(),
        splashFactory: widget.disableFeedback ? NoSplash.splashFactory : null,
        highlightColor: widget.disableFeedback ? Colors.transparent : null,
        child: SizedBox(
          height: 64,
          child: Center(
            child: Icon(
              Icons.backspace_outlined,
              color: context.colour.surfaceContainerLow,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              numPadButton(context, '1'),
              numPadButton(context, '2'),
              numPadButton(context, '3'),
            ],
          ),
          Row(
            children: [
              numPadButton(context, '4'),
              numPadButton(context, '5'),
              numPadButton(context, '6'),
            ],
          ),
          Row(
            children: [
              numPadButton(context, '7'),
              numPadButton(context, '8'),
              numPadButton(context, '9'),
            ],
          ),
          Row(
            children: [
              if (widget.mode == DialPadMode.double) numPadButton(context, '.'),
              numPadButton(context, '0'),
              backspaceButton(context),
            ],
          ),
        ],
      ),
    );
  }
}
