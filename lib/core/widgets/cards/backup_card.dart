import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class BackupCard extends StatelessWidget {
  const BackupCard({super.key, required this.onTap});

  final Function onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colour.secondary,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          children: [
            Image.asset(Assets.misc.passwordbook.path, height: 32, width: 32),
            const Gap(16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BBText(
                  'Protect your bitcoin.',
                  style: context.font.bodyMedium,
                  color: context.colour.onPrimary,
                ),
                BBText(
                  'Back up your wallet now.',
                  style: context.font.bodyMedium,
                  color: context.colour.surfaceContainer,
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.arrow_forward, color: context.colour.onPrimary),
          ],
        ),
      ),
    );
  }
}
