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
          method: FundingMethod.sinpe,
          title: 'SINPE Móvil',
          subtitle: 'Transfiere Colones usando SINPE',
        ),
        Gap(16.0),
        FundExchangeMethodListTile(
          method: FundingMethod.crIbanCrc,
          title: 'IBAN Costa Rica (CRC)',
          subtitle: 'Transfiere fondos en Colón Costarricense (CRC)',
        ),
        Gap(16.0),
        FundExchangeMethodListTile(
          method: FundingMethod.crIbanUsd,
          title: 'IBAN Costa Rica (USD)',
          subtitle: 'Transfiere fondos en Dólares Estadounidenses (USD)',
        ),
      ],
    );
  }
}
