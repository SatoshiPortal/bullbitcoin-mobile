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

class FundExchangeRegularSepaScreen extends StatelessWidget {
  const FundExchangeRegularSepaScreen({super.key});

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
              BBText('SEPA transfer', style: theme.textTheme.displaySmall),
              const Gap(16.0),
              RichText(
                text: TextSpan(
                  text:
                      "Send a SEPA transfer from your bank account using the details below ",
                  style: theme.textTheme.headlineSmall,
                  children: [
                    TextSpan(
                      text: 'exactly.',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(24.0),
              if (failedToLoadFundingDetails ||
                  details is! RegularSepaFundingDetails?) ...[
                const FundExchangeDetailsErrorCard(),
                const Gap(24.0),
              ] else ...[
                InfoCard(
                  description:
                      'Only use for transactions above €20,000. For smaller transactions, use the Instant SEPA option.',
                  tagColor: theme.colorScheme.secondary,
                  bgColor: theme.colorScheme.inverseSurface.withValues(
                    alpha: 0.1,
                  ),
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: 'IBAN account number',
                  value: details?.iban,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: 'Recipient name',
                  value: details?.beneficiaryName,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: 'Transfer code (add this as payment description)',
                  value: details?.code,
                ),
                const Gap(16.0),
                InfoCard(
                  bgColor: theme.colorScheme.inverseSurface.withValues(
                    alpha: 0.1,
                  ),
                  tagColor: theme.colorScheme.secondary,
                  description:
                      'In the payment description, add your transfer code.',
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: 'Bank country',
                  value: details?.bankCountry,
                ),
                const Gap(24.0),
                FundExchangeDetail(label: 'BIC code', value: details?.bic),
                const Gap(24.0),
                FundExchangeDetail(
                  label: 'Recipient address',
                  value: details?.beneficiaryAddress,
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
