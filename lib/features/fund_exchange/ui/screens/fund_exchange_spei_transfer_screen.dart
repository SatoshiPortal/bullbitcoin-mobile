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

class FundExchangeSpeiTransferScreen extends StatelessWidget {
  const FundExchangeSpeiTransferScreen({super.key});

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
              BBText('SPEI transfer', style: theme.textTheme.displaySmall),
              const Gap(16.0),
              Text(
                "Transfer funds using your CLABE",
                style: theme.textTheme.headlineSmall,
              ),
              const Gap(24.0),
              if (failedToLoadFundingDetails ||
                  details is! SpeiFundingDetails?) ...[
                const FundExchangeDetailsErrorCard(),
                const Gap(24.0),
              ] else ...[
                InfoCard(
                  bgColor: theme.colorScheme.inverseSurface.withValues(
                    alpha: 0.1,
                  ),
                  tagColor: theme.colorScheme.secondary,
                  description: 'Make a deposit using SPEI transfer (instant).',
                ),
                const Gap(24.0),
                FundExchangeDetail(label: 'CLABE', value: details?.clabe),
                const Gap(24.0),
                FundExchangeDetail(
                  label: 'Beneficiary name',
                  value: details?.beneficiaryName,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: 'Bank name',
                  value: details?.bankName,
                ),
                const Gap(24.0),
                FundExchangeDetail(label: 'Memo', value: details?.code),
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
