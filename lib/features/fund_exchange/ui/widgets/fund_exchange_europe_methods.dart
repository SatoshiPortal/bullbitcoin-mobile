import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_method_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class FundExchangeEuropeMethods extends StatelessWidget {
  const FundExchangeEuropeMethods({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FundExchangeMethodListTile(
          method: FundingMethod.instantSepa,
          title: 'Instant SEPA',
          subtitle: 'Fastest - Only for transactions below €20,000',
        ),
        Gap(16.0),
        FundExchangeMethodListTile(
          method: FundingMethod.regularSepa,
          title: 'Regular SEPA',
          subtitle: 'Only use for larger transactions above €20,000',
        ),
      ],
    );
  }
}
