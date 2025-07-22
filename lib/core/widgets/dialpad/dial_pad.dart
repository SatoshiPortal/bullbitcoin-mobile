import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';

class DialPad extends StatelessWidget {
  const DialPad({
    super.key,
    required this.onNumberPressed,
    required this.onBackspacePressed,
    this.disableFeedback = false,
  });

  final Function(String) onNumberPressed;
  final Function() onBackspacePressed;
  final bool disableFeedback;

  Widget numPadButton(BuildContext context, String num) {
    return Expanded(
      child: InkWell(
        onTap: () => onNumberPressed(num),
        splashFactory: disableFeedback ? NoSplash.splashFactory : null,
        highlightColor: disableFeedback ? Colors.transparent : null,
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
        onTap: onBackspacePressed,
        splashFactory: disableFeedback ? NoSplash.splashFactory : null,
        highlightColor: disableFeedback ? Colors.transparent : null,
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
              numPadButton(context, '.'),
              numPadButton(context, '0'),
              backspaceButton(context),
            ],
          ),
        ],
      ),
    );
  }
}
