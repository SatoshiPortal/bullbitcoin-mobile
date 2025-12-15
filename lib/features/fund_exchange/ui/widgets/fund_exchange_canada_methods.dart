import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_method_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class FundExchangeCanadaMethods extends StatelessWidget {
  const FundExchangeCanadaMethods({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        FundExchangeMethodListTile(
          method: FundingMethod.emailETransfer,
          title: context.loc.fundExchangeMethodEmailETransfer,
          subtitle: context.loc.fundExchangeMethodEmailETransferSubtitle,
        ),
        const Gap(16.0),
        FundExchangeMethodListTile(
          method: FundingMethod.bankTransferWire,
          title: context.loc.fundExchangeMethodBankTransferWire,
          subtitle: context.loc.fundExchangeMethodBankTransferWireSubtitle,
        ),
        const Gap(16.0),
        FundExchangeMethodListTile(
          method: FundingMethod.onlineBillPayment,
          title: context.loc.fundExchangeMethodOnlineBillPayment,
          subtitle: context.loc.fundExchangeMethodOnlineBillPaymentSubtitle,
        ),
        const Gap(16.0),
        FundExchangeMethodListTile(
          method: FundingMethod.canadaPost,
          title: context.loc.fundExchangeMethodCanadaPost,
          subtitle: context.loc.fundExchangeMethodCanadaPostSubtitle,
        ),
      ],
    );
  }
}
