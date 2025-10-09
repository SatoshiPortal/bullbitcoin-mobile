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
  String text = '';
  bool get hasDot => text.contains('.');

  void onTextChanged(String num) {
    switch (widget.mode) {
      case DialPadMode.int:
        final intValue = int.tryParse(text + num);
        if (intValue == null) break;
        text = intValue.toString();
      case DialPadMode.double:
        if (hasDot && num == '.') break;
        if (!hasDot && num == '.') {
          text = text + num;
          break;
        }
        if (!hasDot && num != '.') {
          final intValue = int.tryParse(text + num);
          if (intValue == null) break;
          text = intValue.toString();
          break;
        }
        if (hasDot) {
          final doubleValue = double.tryParse(text + num);
          if (doubleValue == null) break;
          text = text + num; // or you wont have 0
          break;
        }
      case DialPadMode.pin:
        text += num;
    }

    widget.onChanged(text);
  }

  void onBackspacePressed() {
    if (text.isEmpty) return;
    text = text.substring(0, text.length - 1);

    widget.onChanged(text);
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
