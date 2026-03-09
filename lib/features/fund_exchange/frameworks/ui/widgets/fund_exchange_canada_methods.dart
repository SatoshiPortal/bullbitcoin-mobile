import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/frameworks/ui/widgets/fund_exchange_method_list_tile.dart';
import 'package:bb_mobile/features/fund_exchange/interface_adapters/presentation/bloc/fund_exchange_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class FundExchangeCanadaMethods extends StatelessWidget {
  const FundExchangeCanadaMethods({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        FundExchangeMethodListTile(
          title: context.loc.fundExchangeMethodEmailETransfer,
          subtitle: context.loc.fundExchangeMethodEmailETransferSubtitle,
          onTap: () {
            context.read<FundExchangeBloc>().add(
              const FundExchangeEvent.fundingDetailsRequested(
                fundingMethod: EmailETransfer(),
              ),
            );
          },
        ),
        const Gap(16.0),
        FundExchangeMethodListTile(
          title: context.loc.fundExchangeMethodBankTransferWire,
          subtitle: context.loc.fundExchangeMethodBankTransferWireSubtitle,
          onTap: () {
            context.read<FundExchangeBloc>().add(
              const FundExchangeEvent.fundingDetailsRequested(
                fundingMethod: BankTransferWire(),
              ),
            );
          },
        ),
        const Gap(16.0),
        FundExchangeMethodListTile(
          title: context.loc.fundExchangeMethodOnlineBillPayment,
          subtitle: context.loc.fundExchangeMethodOnlineBillPaymentSubtitle,
          onTap: () {
            context.read<FundExchangeBloc>().add(
              const FundExchangeEvent.fundingDetailsRequested(
                fundingMethod: OnlineBillPayment(),
              ),
            );
          },
        ),
        const Gap(16.0),
        FundExchangeMethodListTile(
          title: context.loc.fundExchangeMethodCanadaPost,
          subtitle: context.loc.fundExchangeMethodCanadaPostSubtitle,
          onTap: () {
            context.read<FundExchangeBloc>().add(
              const FundExchangeEvent.fundingDetailsRequested(
                fundingMethod: CanadaPost(),
              ),
            );
          },
        ),
      ],
    );
  }
}
