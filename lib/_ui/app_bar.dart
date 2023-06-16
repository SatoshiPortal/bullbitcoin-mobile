import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class BBAppBar extends StatelessWidget {
  const BBAppBar({this.buttonKey, required this.text, this.onBack});

  final String text;
  final Function()? onBack;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colour.background,
      height: double.infinity,
      child: Padding(
        padding: const EdgeInsets.only(
          right: 16.0,
          bottom: 16,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (onBack != null)
              IconButton(
                key: buttonKey,
                icon: const FaIcon(FontAwesomeIcons.angleLeft),
                padding: const EdgeInsets.fromLTRB(16, 24, 0, 0),
                onPressed: onBack,
                color: context.colour.onBackground,
              ).animate(delay: 100.ms).fadeIn(),
            const Spacer(),
            BBText.titleLarge(
              text,
              isBold: true,
            ).animate(delay: 300.ms).fadeIn().slideY(),
          ],
        ),
      ),
    );
  }
}
