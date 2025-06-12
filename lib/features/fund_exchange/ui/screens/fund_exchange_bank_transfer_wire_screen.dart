import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_detail.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_done_bottom_navigation_bar.dart';
import 'package:bb_mobile/ui/components/cards/info_card.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class FundExchangeBankTransferWireScreen extends StatelessWidget {
  const FundExchangeBankTransferWireScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final code = context.select(
      (FundExchangeBloc bloc) => bloc.state.bankTransferWireCode,
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
              const FundExchangeDetail(
                label: 'Beneficiary name',
                helpText:
                    'Use our official corporate name. Do not use "Bull Bitcoin".',
                value: 'Satoshi Portal Inc.',
              ),
              const Gap(24.0),
              FundExchangeDetail(
                label: 'Transfer code (add this as a payment description)',
                helpText: 'Add this as the reason for the transfer',
                value: code,
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
              const FundExchangeDetail(
                label: 'Bank account details',
                value: '899-66439-86731649741',
              ),
              const Gap(24.0),
              const FundExchangeDetail(
                label: 'SWIFT code',
                value: 'CUCXCATTCAL',
              ),
              const Gap(24.0),
              const FundExchangeDetail(
                label: 'Institution number',
                value: '899',
              ),
              const Gap(24.0),
              const FundExchangeDetail(label: 'Transit number', value: '66439'),
              const Gap(24.0),
              const FundExchangeDetail(
                label: 'Routing number',
                value: '89966439',
              ),
              const Gap(24.0),
              const FundExchangeDetail(
                label: 'Beneficiary address',
                value: '4004 8 St SE, Calgary, AB T2G 2W3',
              ),
              const Gap(24.0),
              const FundExchangeDetail(
                label: 'Bank name',
                value: 'SERVUS CREDIT UNION LTD',
              ),
              const Gap(24.0),
              const FundExchangeDetail(
                label: 'Address of our bank',
                value: '102, 420 2nd Street SW, Calgary, Alberta T2P3K4',
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
