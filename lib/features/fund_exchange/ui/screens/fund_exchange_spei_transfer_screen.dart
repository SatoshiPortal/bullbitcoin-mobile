import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_detail.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_done_bottom_navigation_bar.dart';
import 'package:bb_mobile/ui/components/cards/info_card.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class FundExchangeSpeiTransferScreen extends StatelessWidget {
  const FundExchangeSpeiTransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final memo = context.select(
      (FundExchangeBloc bloc) => bloc.state.speiTransferMemo,
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
              BBText('SPEI transfer', style: theme.textTheme.displaySmall),
              const Gap(16.0),
              Text(
                "Transfer funds using your CLABE",
                style: theme.textTheme.headlineSmall,
              ),
              const Gap(24.0),
              InfoCard(
                bgColor: theme.colorScheme.inverseSurface.withValues(
                  alpha: 0.1,
                ),
                tagColor: theme.colorScheme.secondary,
                description: 'Make a deposit using SPEI transfer (instant).',
              ),
              const Gap(24.0),
              const FundExchangeDetail(
                label: 'CLABE',
                value: '710969000036061334',
              ),
              const Gap(24.0),
              const FundExchangeDetail(
                label: 'Beneficiary name',
                value: 'TORO PAGOS',
              ),
              const Gap(24.0),
              FundExchangeDetail(label: 'Memo', value: memo),
              const Gap(24.0),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const FundExchangeDoneBottomNavigationBar(),
    );
  }
}
