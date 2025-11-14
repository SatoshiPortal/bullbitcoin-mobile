import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_method_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class FundExchangeCostaRicaMethods extends StatelessWidget {
  const FundExchangeCostaRicaMethods({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FundExchangeMethodListTile(
          method: FundingMethod.sinpe,
          title: context.loc.fundExchangeCostaRicaMethodSinpeTitle,
          subtitle: context.loc.fundExchangeCostaRicaMethodSinpeSubtitle,
        ),
        const Gap(16.0),
        FundExchangeMethodListTile(
          method: FundingMethod.crIbanCrc,
          title: context.loc.fundExchangeCostaRicaMethodIbanCrcTitle,
          subtitle: context.loc.fundExchangeCostaRicaMethodIbanCrcSubtitle,
        ),
        const Gap(16.0),
        FundExchangeMethodListTile(
          method: FundingMethod.crIbanUsd,
          title: context.loc.fundExchangeCostaRicaMethodIbanUsdTitle,
          subtitle: context.loc.fundExchangeCostaRicaMethodIbanUsdSubtitle,
        ),
      ],
    );
  }
}
