import 'package:bb_mobile/_ui/components/text/text.dart';
import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DialPad extends StatelessWidget {
  final void Function(String)? onTap;
  final void Function()? onDelete;
  const DialPad({super.key, required this.onTap, this.onDelete});
  Widget deleteButton(BuildContext context) {
    return Expanded(
      child: IconButton(
        iconSize: 32,
        color: context.colour.onPrimaryContainer,
        splashColor: Colors.transparent,
        onPressed: () {
          SystemSound.play(SystemSoundType.click);
          HapticFeedback.mediumImpact();
          onDelete?.call();
        },
        icon: Icon(
          CupertinoIcons.delete_left,
          size: 32,
          color: context.colour.surfaceContainerLow,
        ),
      ),
    );
  }

  Widget numPadButton(BuildContext context, String num) {
    return Expanded(
      child: InkWell(
        onTap: () {
          SystemSound.play(SystemSoundType.click);
          HapticFeedback.mediumImpact();
          onTap?.call(num);
        },
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
              deleteButton(context),
            ],
          ),
        ],
      ),
    );
  }
}
