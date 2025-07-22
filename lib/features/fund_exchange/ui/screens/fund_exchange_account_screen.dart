import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_jurisdiction.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_canada_methods.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_costa_rica_methods.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_jurisdiction_dropdown.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_method_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class FundExchangeAccountScreen extends StatelessWidget {
  const FundExchangeAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final jurisdiction = context.select(
      (FundExchangeBloc bloc) => bloc.state.jurisdiction,
    );

    return Scaffold(
      appBar: AppBar(
        // Adding the leading icon button here manually since we are in the first
        // route of a shellroute and so no back button is provided by default.
        leading:
            context.canPop()
                ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    context.pop();
                  },
                )
                : null,
        title: const Text('Funding'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // or start, end, etc.
            children: [
              const Gap(24.0),
              CircleAvatar(
                radius: 32,
                backgroundColor: theme.colorScheme.secondaryContainer,
                child: Icon(
                  Icons.account_balance,
                  size: 24,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const Gap(8.0),
              BBText('Fund your account', style: theme.textTheme.displaySmall),
              const Gap(8.0),
              BBText(
                'Select your country and payment method',
                style: theme.textTheme.headlineSmall,
              ),
              const Gap(24.0),
              const FundExchangeJurisdictionDropdown(),
              const Gap(24.0),
              switch (jurisdiction) {
                FundingJurisdiction.canada => const FundExchangeCanadaMethods(),
                FundingJurisdiction.europe => const FundExchangeMethodListTile(
                  method: FundingMethod.sepaTransfer,
                  title: 'SEPA transfer',
                  subtitle: 'Send a SEPA transfer from your bank',
                ),
                FundingJurisdiction.mexico => const FundExchangeMethodListTile(
                  method: FundingMethod.speiTransfer,
                  title: 'SPEI transfer',
                  subtitle: 'Transfer funds using your CLABE',
                ),
                FundingJurisdiction.costaRica =>
                  const FundExchangeCostaRicaMethods(),
              },
            ],
          ),
        ),
      ),
    );
  }
}
