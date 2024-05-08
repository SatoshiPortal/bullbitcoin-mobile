import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class BBHeader extends StatelessWidget {
  const BBHeader.popUpCenteredText({
    required this.text,
    this.leftChild,
    this.showBack = true,
    this.isLeft = false,
    this.onBack,
  });

  final String text;
  final Widget? leftChild;
  final bool showBack;
  final bool isLeft;
  final Function? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!isLeft) const Spacer(flex: 2),
          if (leftChild != null)
            leftChild!
          else
            BBText.titleLarge(
              text,
              textAlign: isLeft ? TextAlign.left : TextAlign.center,
              isBold: true,
            ),
          const Spacer(),
          if (showBack)
            IconButton(
              icon: const FaIcon(FontAwesomeIcons.xmark),
              color: context.colour.onBackground,
              onPressed: () {
                if (onBack == null)
                  Navigator.of(context).pop();
                else
                  onBack!();
              },
            ),
        ],
      ),
    );
  }
}
