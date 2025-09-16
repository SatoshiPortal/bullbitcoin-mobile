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

class FundExchangeCrIbanUsdScreen extends StatelessWidget {
  const FundExchangeCrIbanUsdScreen({super.key});

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
              BBText(
                'Bank Transfer (USD)',
                style: theme.textTheme.displaySmall,
              ),
              const Gap(16.0),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text:
                          "Send a bank transfer from your bank account using the details below ",
                      style: theme.textTheme.headlineSmall,
                    ),
                    TextSpan(
                      text: "exactly",
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text:
                          ". The funds will be added to your account balance.",
                      style: theme.textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
              const Gap(24.0),
              if (failedToLoadFundingDetails ||
                  details is! CrIbanUsdFundingDetails?) ...[
                const FundExchangeDetailsErrorCard(),
                const Gap(24.0),
              ] else ...[
                FundExchangeDetail(
                  label: 'IBAN account number (for US dollars only)',
                  value: details?.iban,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: 'Payment description',
                  value: details?.code,
                  helpText: 'Your transfer code.',
                ),
                const Gap(16.0),
                InfoCard(
                  description:
                      'You must add the transfer code as the "message" or "reason" or "description" when making the payment. If you forget to put this code your payment may be rejected.',
                  bgColor: theme.colorScheme.inverseSurface.withValues(
                    alpha: 0.1,
                  ),
                  tagColor: theme.colorScheme.secondary,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: 'Recipient name',
                  value: details?.beneficiaryName,
                  helpText:
                      'Use our official corporate name. Do not use "Bull Bitcoin".',
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: 'Cédula Jurídica',
                  value: details?.cedulaJuridica,
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
