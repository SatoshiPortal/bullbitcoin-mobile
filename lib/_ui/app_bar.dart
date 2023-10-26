import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/styles.dart';
import 'package:extra_alignments/extra_alignments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (onBack != null) ...[
            BottomCenter(
              child: IconButton(
                key: buttonKey,
                icon: const FaIcon(FontAwesomeIcons.angleLeft),
                padding: EdgeInsets.zero,
                onPressed: onBack,
                color: context.colour.onBackground,
              ).animate(delay: 100.ms).fadeIn(),
            ),
          ],
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: BBText.titleLarge(
              text,
              isBold: true,
            ).animate(delay: 300.ms).fadeIn().slideY(),
          ),
          const Gap(16),
        ],
      ),
    );
  }
}
