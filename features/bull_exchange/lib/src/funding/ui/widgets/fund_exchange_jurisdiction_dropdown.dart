import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_ui/bull_ui.dart' show BullDropdown, BullPickerItem;
import 'package:exchange/exchange.dart';
import 'package:material_ui/material_ui.dart';

class FundExchangeJurisdictionDropdown extends StatelessWidget {
  final Jurisdiction value;
  final void Function(Jurisdiction)? onChanged;
  const FundExchangeJurisdictionDropdown({
    super.key,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BullDropdown<Jurisdiction>(
      value: value,
      items: [
        BullPickerItem(
          value: Jurisdiction.canada,
          label: context.loc.fundExchangeJurisdictionCanada,
        ),
        BullPickerItem(
          value: Jurisdiction.europe,
          label: context.loc.fundExchangeJurisdictionEurope,
        ),
        BullPickerItem(
          value: Jurisdiction.mexico,
          label: context.loc.fundExchangeJurisdictionMexico,
        ),
        BullPickerItem(
          value: Jurisdiction.costaRica,
          label: context.loc.fundExchangeJurisdictionCostaRica,
        ),
        BullPickerItem(
          value: Jurisdiction.argentina,
          label: context.loc.fundExchangeJurisdictionArgentina,
        ),
        BullPickerItem(
          value: Jurisdiction.colombia,
          label: context.loc.fundExchangeJurisdictionColombia,
        ),
      ],
      onChanged: onChanged,
    );
  }
}
