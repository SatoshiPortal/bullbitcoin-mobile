import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
// CustomFeeListItem owns the fee input/controller integration; keep this
// application-coupled widget while migrating the surrounding presentation.
import 'package:bb_mobile/core/widgets/fees/custom_fee_list_item.dart';
import 'package:bb_mobile/features/replace_by_fee/domain/fee_entity.dart';
import 'package:bull_ui/bull_ui.dart';

class BumpFeeSelectorWidget extends StatelessWidget {
  const BumpFeeSelectorWidget({
    super.key,
    required this.fastestFeeRate,
    required this.selected,
    required this.txSize,
    required this.onChanged,
    required this.onInvalid,
    required this.focusNode,
    this.minRelay,
  });

  final FeeEntity fastestFeeRate;
  final FeeEntity selected;
  final int txSize;
  final void Function(FeeEntity fee) onChanged;

  /// Called when the custom bump field goes below the relay floor or is
  /// emptied — see [CustomFeeListItem.onInvalid].
  final VoidCallback onInvalid;
  final FocusNode focusNode;

  /// Live relay floor for the custom bump field (null → static 0.1).
  final RelativeFee? minRelay;

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
              minRelay: minRelay,
              txSize: txSize,
              exchangeRate: 0.0,
              fiatCurrencyCode: '',
              defaultAbsolute: false,
              tileColor: context.bull.onSecondary,
              tileShadowColor: context.bull.secondary,
              unselectedIconColor: context.bull.surface,
              allowAbsoluteToggle: false,
              commitOnChange: true,
              focusNode: focusNode,
              onInvalid: onInvalid,
              onCommit: (fee) async {
                // Safe cast: allowAbsoluteToggle is false so the widget
                // only ever produces a RelativeFee here.
                onChanged(
                  FeeEntity(type: FeeType.custom, feeRate: fee as RelativeFee),
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
    return BullBorderedTile(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: .spaceBetween,
        crossAxisAlignment: .start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                BullText(
                  context.loc.replaceByFeeFastestTitle,
                  style: context.bullText.headlineLarge,
                ),
                const Gap(4),
                BullText(
                  context.loc.replaceByFeeFastestDescription,
                  style: context.bullText.labelMedium,
                ),
                const Gap(2),
                BullText(
                  context.loc.replaceByFeeFeeRateDisplay(
                    fastestFeeRate.feeRate.satPerVbyte.toStringAsFixed(1),
                  ),
                  style: context.bullText.labelMedium,
                ),
              ],
            ),
          ),
          BullIcon(
            isSelected ? BullIcons.checkCircle : BullIcons.close,
            color: isSelected ? context.bull.primary : context.bull.surface,
          ),
        ],
      ),
    );
  }
}
