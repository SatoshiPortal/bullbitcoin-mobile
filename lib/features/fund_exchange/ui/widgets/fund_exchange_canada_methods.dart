import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_method_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class FundExchangeCanadaMethods extends StatelessWidget {
  const FundExchangeCanadaMethods({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FundExchangeMethodListTile(
          method: FundingMethod.emailETransfer,
          title: 'Email E-Transfer',
          subtitle: 'Easiest and fastest method (instant)',
        ),
        Gap(16.0),
        FundExchangeMethodListTile(
          method: FundingMethod.bankTransferWire,
          title: 'Bank Transfer (Wire or EFT)',
          subtitle:
              'Best and most reliable option for larger amounts (same or next day)',
        ),
        Gap(16.0),
        FundExchangeMethodListTile(
          method: FundingMethod.onlineBillPayment,
          title: 'Online Bill Payment',
          subtitle:
              'Slowest option, but can be done via online banking (3-4 business days)',
        ),
        Gap(16.0),
        FundExchangeMethodListTile(
          method: FundingMethod.canadaPost,
          title: 'In-person cash or debit at Canada Post',
          subtitle: 'Best for those who prefer to pay in person',
        ),
      ],
    );
  }
}
