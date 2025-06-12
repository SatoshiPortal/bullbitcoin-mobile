import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_detail.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_done_bottom_navigation_bar.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class FundExchangeOnlineBillPaymentScreen extends StatelessWidget {
  const FundExchangeOnlineBillPaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accountNumber = context.select(
      (FundExchangeBloc bloc) => bloc.state.onlineBillPaymentAccountNumber,
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
                'Online Bill Payment',
                style: theme.textTheme.displaySmall,
              ),
              const Gap(16.0),
              BBText(
                "Any amount you send via your bank's online bill payment feature using the information below will be credited to your Bull Bitcoin account balance within 3-4 business days.",
                style: theme.textTheme.headlineSmall,
              ),
              const Gap(24.0),
              const FundExchangeDetail(
                label: "Search your bank's list of billers for this name",
                helpText:
                    "Add this company as a payee - it's Bull Bitcoin's payment processor",
                value: 'Apaylo Finance Technology',
              ),
              const Gap(24.0),
              FundExchangeDetail(
                label: 'Add this as the account number',
                helpText: 'This unique account number is created just for you',
                value: accountNumber,
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
