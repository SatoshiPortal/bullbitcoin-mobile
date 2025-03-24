import 'package:bb_mobile/_ui/components/text/text.dart';
import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:flutter/material.dart';

class DialPad extends StatelessWidget {
  final void Function(String)? onTap;
  const DialPad({super.key, required this.onTap});

  Widget numPadButton(BuildContext context, String num) {
    return Expanded(
      child: InkWell(
        onTap: () => onTap?.call(num),
        child: Container(
          height: 64,
          decoration: const BoxDecoration(
              // border: Border.all(
              //   color: context.colour.surface,
              // ),
              ),
          child: Center(
            child: BBText(
              num,
              style: context.font.headlineMedium!.copyWith(fontSize: 20),
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
              numPadButton(context, ''),
            ],
          ),
        ],
      ),
    );
  }
}
