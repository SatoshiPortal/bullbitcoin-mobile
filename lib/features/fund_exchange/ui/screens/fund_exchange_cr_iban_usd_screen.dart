import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_detail.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_done_bottom_navigation_bar.dart';
import 'package:bb_mobile/ui/components/cards/info_card.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class FundExchangeCrIbanUsdScreen extends StatelessWidget {
  const FundExchangeCrIbanUsdScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                'Costa Rica IBAN (USD)',
                style: theme.textTheme.displaySmall,
              ),
              const Gap(16.0),
              Text(
                "Transfer funds in US Dollars (USD)",
                style: theme.textTheme.headlineSmall,
              ),
              const Gap(24.0),
              InfoCard(
                bgColor: theme.colorScheme.inverseSurface.withValues(
                  alpha: 0.1,
                ),
                tagColor: theme.colorScheme.secondary,
                description: '',
              ),
              const Gap(24.0),
              const FundExchangeDetail(label: '', value: ''),
              const Gap(24.0),
              const FundExchangeDetail(label: '', value: ''),
              const Gap(24.0),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const FundExchangeDoneBottomNavigationBar(),
    );
  }
}
