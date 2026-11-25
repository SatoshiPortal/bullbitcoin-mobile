import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_ui/bull_ui.dart' show BullDropdown, BullPickerItem;
import 'package:exchange/exchange.dart';
import 'package:material_ui/material_ui.dart';

/// The fund jurisdictions. [value] is null when the account currency gives
/// none: the hint asks the user to pick.
class FundExchangeJurisdictionDropdown extends StatelessWidget {
  final Jurisdiction? value;
  final void Function(Jurisdiction) onChanged;
  const FundExchangeJurisdictionDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BullDropdown<Jurisdiction>(
      value: value,
      hint: context.loc.fundExchangeJurisdictionHint,
      items: [
        for (final jurisdiction in Jurisdiction.values)
          BullPickerItem(
            value: jurisdiction,
            label: switch (jurisdiction) {
              Jurisdiction.canada => context.loc.fundExchangeJurisdictionCanada,
              Jurisdiction.europe => context.loc.fundExchangeJurisdictionEurope,
              Jurisdiction.mexico => context.loc.fundExchangeJurisdictionMexico,
              Jurisdiction.costaRica =>
                context.loc.fundExchangeJurisdictionCostaRica,
              Jurisdiction.argentina =>
                context.loc.fundExchangeJurisdictionArgentina,
              Jurisdiction.colombia =>
                context.loc.fundExchangeJurisdictionColombia,
            },
          ),
      ],
      onChanged: onChanged,
    );
  }
}
