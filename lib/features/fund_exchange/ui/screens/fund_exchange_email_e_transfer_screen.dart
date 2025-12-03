import 'package:bb_mobile/core/exchange/domain/entity/funding_details.dart';
// ignore: unused_import
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_detail.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_details_error_card.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_done_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class FundExchangeEmailETransferScreen extends StatelessWidget {
  const FundExchangeEmailETransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = context.select(
      (FundExchangeBloc bloc) => bloc.state.fundingDetails,
    );
    final userSummary = context.select(
      (FundExchangeBloc bloc) => bloc.state.userSummary,
    );
    final failedToLoadFundingDetails = context.select(
      (FundExchangeBloc bloc) => bloc.state.failedToLoadFundingDetails,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.fundExchangeTitle),
        scrolledUnderElevation: 0.0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: .center,
            crossAxisAlignment: .start,
            children: [
              BBText(
                context.loc.fundExchangeETransferTitle,
                style: theme.textTheme.displaySmall,
              ),
              const Gap(16.0),
              BBText(
                context.loc.fundExchangeETransferDescription,
                style: theme.textTheme.headlineSmall,
              ),
              const Gap(24.0),
              if (failedToLoadFundingDetails ||
                  details is! ETransferFundingDetails?) ...[
                const FundExchangeDetailsErrorCard(),
                const Gap(24.0),
              ] else ...[
                FundExchangeDetail(
                  label: context.loc.fundExchangeETransferLabelBeneficiaryName,
                  value: details?.beneficiaryName,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: context.loc.fundExchangeETransferLabelEmail,
                  value: details?.beneficiaryEmail,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: context.loc.fundExchangeETransferLabelSecretQuestion,
                  value: details?.secretQuestion,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: context.loc.fundExchangeETransferLabelSecretAnswer,
                  value: userSummary?.userNumber.toString() ?? '',
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: const FundExchangeDoneBottomNavigationBar(),
    );
  }
}
