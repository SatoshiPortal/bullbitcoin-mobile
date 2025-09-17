import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_method_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class FundExchangeCostaRicaMethods extends StatelessWidget {
  const FundExchangeCostaRicaMethods({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FundExchangeMethodListTile(
          method: FundingMethod.sinpeTransfer,
          title: 'SINPE Transfer',
          subtitle: 'Transfer Colones using SINPE',
        ),
        Gap(16.0),
        FundExchangeMethodListTile(
          method: FundingMethod.crIbanCrc,
          title: 'Costa Rica IBAN (CRC)',
          subtitle: 'Transfer funds in Costa Rican Colón (CRC)',
        ),
        Gap(16.0),
        FundExchangeMethodListTile(
          method: FundingMethod.crIbanUsd,
          title: 'Costa Rica IBAN (USD)',
          subtitle: 'Transfer funds in US Dollars (USD)',
        ),
      ],
    );
  }
}
