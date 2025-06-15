import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_detail.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_done_bottom_navigation_bar.dart';
import 'package:bb_mobile/ui/components/cards/info_card.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class FundExchangeSepaTransferScreen extends StatelessWidget {
  const FundExchangeSepaTransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final code = context.select(
      (FundExchangeBloc bloc) => bloc.state.fundingDetails?.code,
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
              BBText('SEPA transfer', style: theme.textTheme.displaySmall),
              const Gap(16.0),
              RichText(
                text: TextSpan(
                  text:
                      "Send a SEPA transfer from your bank account using the details below ",
                  style: theme.textTheme.headlineSmall,
                  children: [
                    TextSpan(
                      text: 'exactly',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: '. Make sure to select the SEPA INSTANT option.',
                      style: theme.textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
              const Gap(24.0),
              const FundExchangeDetail(
                label: 'IBAN account number',
                value: 'GB94CLJU00997129900518',
              ),
              const Gap(24.0),
              const FundExchangeDetail(
                label: 'Beneficiary name',
                value: 'LEONOD',
              ),
              const Gap(16.0),
              InfoCard(
                bgColor: theme.colorScheme.inverseSurface.withValues(
                  alpha: 0.1,
                ),
                tagColor: theme.colorScheme.secondary,
                description:
                    'The name of the beneficiary should be LEONOD. If you put anything else, your payment will be rejected.',
              ),
              const Gap(24.0),
              FundExchangeDetail(
                label: 'Transfer code (add this as payment description)',
                value: code,
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
              const FundExchangeDetail(
                label: 'Bank account country',
                value: 'United Kingdom',
              ),
              const Gap(16.0),
              InfoCard(
                bgColor: theme.colorScheme.inverseSurface.withValues(
                  alpha: 0.1,
                ),
                tagColor: theme.colorScheme.secondary,
                description: 'Our bank country is the United Kingdom.',
              ),
              const Gap(24.0),
              const FundExchangeDetail(label: 'BIC code', value: 'CLJUGB21'),
              const Gap(24.0),
              const FundExchangeDetail(
                label: 'Beneficiary address',
                helpText:
                    'Our official address, in case this is required by your bank',
                value: '15 PLACE JULES FERRY, 69006, LYON, FRANCE',
              ),
              const Gap(24.0),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const FundExchangeDoneBottomNavigationBar(),
    );
  }
}
