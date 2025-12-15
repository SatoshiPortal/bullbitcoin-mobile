import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/core_deprecated/widgets/text/text.dart';
import 'package:flutter/material.dart';

/// Base DialPad widget for numeric entry (PIN, amount, etc.)
class DialPad extends StatelessWidget {
  const DialPad({
    super.key,
    required this.onNumberPressed,
    required this.onBackspacePressed,
    this.disableFeedback = false,
    this.onlyDigits = false,
  });

  final Function(String) onNumberPressed;
  final Function() onBackspacePressed;
  final bool disableFeedback;
  final bool onlyDigits;

  Widget numPadButton(BuildContext context, String num) {
    return Expanded(
      child: InkWell(
        onTap: () => onNumberPressed(num),
        splashFactory: disableFeedback ? NoSplash.splashFactory : null,
        highlightColor: disableFeedback ? context.appColors.transparent : null,
        child: SizedBox(
          height: 64,
          child: Center(
            child: BBText(
              num,
              style: context.font.headlineMedium?.copyWith(fontSize: 20),
              color: context.appColors.onSurface,
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
        highlightColor: disableFeedback ? context.appColors.transparent : null,
        child: SizedBox(
          height: 64,
          child: Center(
            child: Icon(
              Icons.backspace_outlined,
              color: context.appColors.onSurface,
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
              if (onlyDigits)
                const Expanded(child: SizedBox(height: 64))
              else
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
