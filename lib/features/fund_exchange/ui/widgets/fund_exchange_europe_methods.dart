import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_method_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class FundExchangeEuropeMethods extends StatelessWidget {
  const FundExchangeEuropeMethods({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        FundExchangeMethodListTile(
          method: FundingMethod.instantSepa,
          title: context.loc.fundExchangeMethodInstantSepa,
          subtitle: context.loc.fundExchangeMethodInstantSepaSubtitle,
        ),
        const Gap(16.0),
        FundExchangeMethodListTile(
          method: FundingMethod.regularSepa,
          title: context.loc.fundExchangeMethodRegularSepa,
          subtitle: context.loc.fundExchangeMethodRegularSepaSubtitle,
        ),
      ],
    );
  }
}
