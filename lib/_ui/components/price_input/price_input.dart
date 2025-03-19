import 'package:bb_mobile/_ui/components/text/text.dart';
import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:bb_mobile/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class PriceInput extends StatelessWidget {
  const PriceInput({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BBText(
              '200',
              style: context.font.displaySmall!.copyWith(
                fontSize: 36,
              ),
              color: context.colour.outlineVariant,
            ),
            const Gap(8),
            BBText(
              'sats',
              style: context.font.displaySmall,
              color: context.colour.outlineVariant,
            ),
            const Gap(16),
            InkWell(
              child: Image.asset(
                Assets.images2.dropdownUpdown.path,
                height: 20,
                width: 20,
              ),
            ),
          ],
        ),
        const Gap(14),
        BBText(
          '~0.00 CAD',
          style: context.font.bodyLarge,
          color: context.colour.surfaceContainer,
        ),
        const Gap(14),
        Center(
          child: Container(
            height: 40,
            width: 200,
            alignment: Alignment.center,
            child: Expanded(
              child: TextField(
                textAlignVertical: TextAlignVertical.center,
                textAlign: TextAlign.center,
                expands: true,
                maxLines: null,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(2),
                    borderSide: BorderSide.none,
                  ),
                  fillColor: context.colour.secondaryFixedDim,
                  filled: true,
                  floatingLabelAlignment: FloatingLabelAlignment.center,
                  hintText: 'Add note',
                  hintStyle: context.font.labelSmall!.copyWith(
                    color: context.colour.surfaceContainer,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
