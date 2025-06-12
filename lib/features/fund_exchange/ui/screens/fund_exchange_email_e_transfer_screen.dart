import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_detail.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_done_bottom_navigation_bar.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class FundExchangeEmailETransferScreen extends StatelessWidget {
  const FundExchangeEmailETransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secretQuestion = context.select(
      (FundExchangeBloc bloc) => bloc.state.emailETransferSecretQuestion,
    );
    final secretAnswer = context.select(
      (FundExchangeBloc bloc) => bloc.state.emailETransferSecretAnswer,
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
              BBText('E-Transfer details', style: theme.textTheme.displaySmall),
              const Gap(16.0),
              BBText(
                'Any amount you send from your bank via Email E-Transfer using the information below will be credited to your Bull Bitcoin account balance within a few minutes.',
                style: theme.textTheme.headlineSmall,
              ),
              const Gap(24.0),
              const FundExchangeDetail(
                label: 'Use this as the E-transfer beneficiary name',
                value: 'Satoshi Portal Inc.',
              ),
              const Gap(24.0),
              const FundExchangeDetail(
                label: 'Send the E-transfer to this email',
                value: 'funding@bullaccount.com',
              ),
              const Gap(24.0),
              FundExchangeDetail(
                label: 'Secret question',
                value: secretQuestion,
              ),
              const Gap(24.0),
              FundExchangeDetail(label: 'Secret answer', value: secretAnswer),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const FundExchangeDoneBottomNavigationBar(),
    );
  }
}
