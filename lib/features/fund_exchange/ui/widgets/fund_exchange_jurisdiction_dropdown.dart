import 'package:bull_ui/bull_ui.dart' show BullDropdown, BullPickerItem;
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_jurisdiction.dart';
import 'package:material_ui/material_ui.dart';

class FundExchangeJurisdictionDropdown extends StatelessWidget {
  final FundingJurisdiction value;
  final void Function(FundingJurisdiction)? onChanged;
  const FundExchangeJurisdictionDropdown({
    super.key,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BullDropdown<FundingJurisdiction>(
      value: value,
      items: [
        BullPickerItem(
          value: FundingJurisdiction.canada,
          label: context.loc.fundExchangeJurisdictionCanada,
        ),
        BullPickerItem(
          value: FundingJurisdiction.europe,
          label: context.loc.fundExchangeJurisdictionEurope,
        ),
        BullPickerItem(
          value: FundingJurisdiction.mexico,
          label: context.loc.fundExchangeJurisdictionMexico,
        ),
        BullPickerItem(
          value: FundingJurisdiction.costaRica,
          label: context.loc.fundExchangeJurisdictionCostaRica,
        ),
        BullPickerItem(
          value: FundingJurisdiction.argentina,
          label: context.loc.fundExchangeJurisdictionArgentina,
        ),
        BullPickerItem(
          value: FundingJurisdiction.colombia,
          label: context.loc.fundExchangeJurisdictionColombia,
        ),
      ],
      onChanged: onChanged,
    );
  }
}
