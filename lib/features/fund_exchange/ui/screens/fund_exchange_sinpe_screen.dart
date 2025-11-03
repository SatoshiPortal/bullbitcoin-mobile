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

class FundExchangeSinpeScreen extends StatelessWidget {
  const FundExchangeSinpeScreen({super.key});

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
      appBar: AppBar(title: const Text('Funding'), scrolledUnderElevation: 0.0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BBText('SINPE Movil', style: theme.textTheme.displaySmall),
              const Gap(16.0),
              RichText(
                text: TextSpan(
                  text: 'Send the funds to our SINPE Movil phone number. You ',
                  style: theme.textTheme.headlineSmall,
                  children: [
                    TextSpan(
                      text: 'must',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text:
                          ' send the funds from the same phone number associated to your Bull Bitcoin account. '
                          'If you send the payment from a different number, or if you ask someone else to make the payment for you, ',
                      style: theme.textTheme.headlineSmall,
                    ),
                    TextSpan(
                      text: 'it will be rejected.',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(24.0),
              Text(
                'Once the payment is sent, it will be added to your account balance.',
                style: theme.textTheme.headlineSmall,
              ),
              const Gap(24.0),
              InfoCard(
                description:
                    'Do not put the word "Bitcoin" or "Crypto" in the payment description. This will block your payment. ',
                tagColor: theme.colorScheme.inverseSurface,
                bgColor: theme.colorScheme.inverseSurface.withValues(
                  alpha: 0.1,
                ),
              ),
              const Gap(24.0),
              if (failedToLoadFundingDetails ||
                  details is! SinpeFundingDetails?) ...[
                const FundExchangeDetailsErrorCard(),
                const Gap(24.0),
              ] else ...[
                FundExchangeDetail(
                  label: 'Send to this phone number',
                  value: details?.number,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: 'Recipient name',
                  value: details?.beneficiaryName,
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
