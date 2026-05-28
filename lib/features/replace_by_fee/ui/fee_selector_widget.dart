import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/fees/custom_fee_list_item.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/replace_by_fee/domain/fee_entity.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class BumpFeeSelectorWidget extends StatelessWidget {
  const BumpFeeSelectorWidget({
    super.key,
    required this.fastestFeeRate,
    required this.selected,
    required this.txSize,
    required this.onChanged,
  });

  final FeeEntity fastestFeeRate;
  final FeeEntity selected;
  final int txSize;
  final void Function(FeeEntity fee) onChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            const Gap(16),
            _FastestTile(
              fastestFeeRate: fastestFeeRate,
              isSelected: selected.type == FeeType.fastest,
              onTap: () => onChanged(fastestFeeRate),
            ),
            const Gap(16),
            CustomFeeListItem(
              // Seed from the current selection's rate even when not custom,
              // so tapping the custom tile pre-fills the input with the
              // last-known rate (matches the pre-refactor RBF behaviour).
              initialFee: selected.feeRate,
              isCommittedAsCustom: selected.type == FeeType.custom,
              feePresets: null,
              txSize: txSize,
              exchangeRate: 0.0,
              fiatCurrencyCode: '',
              defaultAbsolute: false,
              tileColor: context.appColors.onSecondary,
              tileShadowColor: context.appColors.secondary,
              unselectedIconColor: context.appColors.surface,
              allowAbsoluteToggle: false,
              commitOnChange: true,
              onCommit: (fee) async {
                // Safe cast: allowAbsoluteToggle is false so the widget
                // only ever produces a RelativeFee here.
                onChanged(
                  FeeEntity(
                    type: FeeType.custom,
                    feeRate: fee as RelativeFee,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FastestTile extends StatelessWidget {
  const _FastestTile({
    required this.fastestFeeRate,
    required this.isSelected,
    required this.onTap,
  });

  final FeeEntity fastestFeeRate;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      radius: 2,
      onTap: onTap,
      child: Material(
        elevation: isSelected ? 4 : 1,
        borderRadius: BorderRadius.circular(2),
        clipBehavior: .hardEdge,
        color: context.appColors.onSecondary,
        shadowColor: context.appColors.secondary,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: .spaceBetween,
            crossAxisAlignment: .start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: .stretch,
                  children: [
                    BBText(
                      context.loc.replaceByFeeFastestTitle,
                      style: context.font.headlineLarge,
                    ),
                    const Gap(4),
                    BBText(
                      context.loc.replaceByFeeFastestDescription,
                      style: context.font.labelMedium,
                    ),
                    const Gap(2),
                    BBText(
                      context.loc.replaceByFeeFeeRateDisplay(
                        fastestFeeRate.feeRate.satPerVbyte.toStringAsFixed(1),
                      ),
                      style: context.font.labelMedium,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.radio_button_checked_outlined,
                color: isSelected
                    ? context.appColors.primary
                    : context.appColors.surface,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
