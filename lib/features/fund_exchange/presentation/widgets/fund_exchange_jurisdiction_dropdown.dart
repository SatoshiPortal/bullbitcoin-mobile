import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/fund_exchange/domain/primitives/funding_jurisdiction.dart';
import 'package:bull_ui/bull_ui.dart';

class FundExchangeJurisdictionDropdown extends StatelessWidget {
  final FundingJurisdiction initialValue;
  final void Function(FundingJurisdiction)? onChanged;
  const FundExchangeJurisdictionDropdown({
    super.key,
    required this.initialValue,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BullDropdown<FundingJurisdiction>(
      value: initialValue,
      items: [
        for (final jurisdiction in FundingJurisdiction.values)
          DropdownMenuItem(
            value: jurisdiction,
            child: BullText(
              _label(context, jurisdiction),
              style: context.bullText.bodyLarge,
            ),
          ),
      ],
      onChanged: (value) {
        if (value != null) onChanged?.call(value);
      },
    );
  }

  String _label(
    BuildContext context,
    FundingJurisdiction value,
  ) => switch (value) {
    FundingJurisdiction.canada => context.loc.fundExchangeJurisdictionCanada,
    FundingJurisdiction.europe => context.loc.fundExchangeJurisdictionEurope,
    FundingJurisdiction.mexico => context.loc.fundExchangeJurisdictionMexico,
    FundingJurisdiction.costaRica =>
      context.loc.fundExchangeJurisdictionCostaRica,
    FundingJurisdiction.argentina =>
      context.loc.fundExchangeJurisdictionArgentina,
    FundingJurisdiction.colombia =>
      context.loc.fundExchangeJurisdictionColombia,
  };
}
