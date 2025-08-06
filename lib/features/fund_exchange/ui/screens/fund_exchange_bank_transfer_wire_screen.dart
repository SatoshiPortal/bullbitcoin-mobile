import 'package:bb_mobile/core/exchange/domain/entity/funding_details.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_detail.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_details_error_card.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_done_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class FundExchangeBankTransferWireScreen extends StatelessWidget {
  const FundExchangeBankTransferWireScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = context.select(
      (FundExchangeBloc bloc) => bloc.state.fundingDetails,
    );
    final failedToLoadFundingDetails = context.select(
      (FundExchangeBloc bloc) => bloc.state.failedToLoadFundingDetails,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Funding')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BBText(
                'Bank transfer (wire)',
                style: theme.textTheme.displaySmall,
              ),
              const Gap(16.0),
              BBText(
                "Send a wire transfer from your bank account using Bull Bitcoin's bank details below. Your bank may require only some parts of these details.",
                style: theme.textTheme.headlineSmall,
              ),
              const Gap(16.0),
              BBText(
                "Any funds you send will be added to your Bull Bitcoin within 1-2 business days.",
                style: theme.textTheme.headlineSmall,
              ),
              const Gap(24.0),
              if (failedToLoadFundingDetails ||
                  details is! WireFundingDetails?) ...[
                const FundExchangeDetailsErrorCard(),
                const Gap(24.0),
              ] else ...[
                FundExchangeDetail(
                  label: 'Beneficiary name',
                  helpText:
                      'Use our official corporate name. Do not use "Bull Bitcoin".',
                  value: details?.beneficiaryName,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: 'Transfer code (add this as a payment description)',
                  helpText: 'Add this as the reason for the transfer',
                  value: details?.code,
                ),
                const Gap(16.0),
                InfoCard(
                  bgColor: theme.colorScheme.inverseSurface.withValues(
                    alpha: 0.1,
                  ),
                  tagColor: theme.colorScheme.secondary,
                  description:
                      'You must add the transfer code as the "message" or "reason" when making the payment.',
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: 'Bank account details',
                  value: details?.bankAccountDetails,
                ),
                const Gap(24.0),
                FundExchangeDetail(label: 'SWIFT code', value: details?.swift),
                const Gap(24.0),
                FundExchangeDetail(
                  label: 'Institution number',
                  value: details?.institutionNumber,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: 'Transit number',
                  value: details?.transitNumber,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: 'Routing number',
                  value: details?.routingNumber,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: 'Beneficiary address',
                  value: details?.beneficiaryAddress,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: 'Bank name',
                  value: details?.bankName,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: 'Address of our bank',
                  value: details?.bankAddress,
                ),
                const Gap(24.0),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: const FundExchangeDoneBottomNavigationBar(),
    );
  }
}
