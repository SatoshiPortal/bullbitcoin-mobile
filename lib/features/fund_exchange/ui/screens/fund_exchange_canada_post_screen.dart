import 'package:bb_mobile/core/exchange/domain/entity/funding_details.dart';
import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_details_error_card.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_done_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:qr_flutter/qr_flutter.dart';

class FundExchangeCanadaPostScreen extends StatelessWidget {
  const FundExchangeCanadaPostScreen({super.key});

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
                'In-person cash or debit at Canada Post',
                style: theme.textTheme.displaySmall,
              ),
              const Gap(16.0),
              ..._steps.map(
                (tactic) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(tactic, style: const TextStyle(fontSize: 14)),
                    ),
                  ],
                ),
              ),
              const Gap(24.0),
              if (failedToLoadFundingDetails ||
                  details is! CanadaPostFundingDetails?) ...[
                const FundExchangeDetailsErrorCard(),
                const Gap(24.0),
              ] else ...[
                Center(
                  child: Column(
                    children: [
                      BBText(
                        "Loadhub QR code",
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const Gap(8.0),
                      if (details?.code == null)
                        const LoadingBoxContent(height: 250.0, width: 250.0)
                      else
                        QrImageView(size: 250, data: details!.code),
                      const Gap(24.0),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: const FundExchangeDoneBottomNavigationBar(),
    );
  }

  List<String> get _steps => const [
    '1. Go to any Canada Post location',
    '2. Ask the cashier to scan the "Loadhub" QR code',
    '3. Tell the cashier the amount you want to load',
    '4. The cashier will ask to see a piece of government-issued ID and verify that the name on your ID matches your Bull Bitcoin account',
    '5. Pay with cash or debit card',
    '6. The cashier will hand you a receipt, keep it as your proof of payment',
    '7. The funds will be added to your Bull Bitcoin account balance within 30 minutes',
  ];
}
