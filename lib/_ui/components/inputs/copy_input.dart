import 'package:bb_mobile/_ui/components/text/text.dart';
import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class CopyInput extends StatelessWidget {
  const CopyInput({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: context.colour.onPrimary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.colour.secondaryFixedDim,
        ),
      ),
      child: Row(
        children: [
          const Gap(15),
          BBText(
            text,
            style: context.font.bodyLarge,
            color: context.colour.secondary,
          ),
          const Spacer(),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            icon: Icon(
              Icons.copy_sharp,
              color: context.colour.secondary,
            ),
            onPressed: () {},
          ),
          const Gap(8),
        ],
      ),
    );
  }
}
