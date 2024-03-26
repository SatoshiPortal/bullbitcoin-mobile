import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';

class WarningContainer extends StatelessWidget {
  const WarningContainer({super.key, required this.title, required this.child, required this.info});

  final String title;
  final Widget child;
  final String info;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border.all(color: context.colour.error, width: 3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BBText.titleLarge(title, isRed: true),
          const Gap(8),
          child,
          const Gap(16),
          Row(
            children: [
              const Icon(FontAwesomeIcons.lightbulb, size: 32),
              const Gap(8),
              Expanded(child: BBText.bodySmall(info, isBold: true)),
            ],
          ),
        ],
      ),
    );
  }
}
