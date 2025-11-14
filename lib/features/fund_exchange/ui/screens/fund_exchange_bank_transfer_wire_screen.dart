import 'package:bb_mobile/core/exchange/domain/entity/funding_details.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_detail.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_details_error_card.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_done_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class FundExchangeBankTransferWireScreen extends StatelessWidget {
  const FundExchangeBankTransferWireScreen({super.key});

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
      appBar: AppBar(
        title: Text(context.loc.fundExchangeTitle),
        scrolledUnderElevation: 0.0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BBText(
                context.loc.fundExchangeBankTransferWireTitle,
                style: theme.textTheme.displaySmall,
              ),
              const Gap(16.0),
              BBText(
                context.loc.fundExchangeBankTransferWireDescription,
                style: theme.textTheme.headlineSmall,
              ),
              const Gap(16.0),
              BBText(
                context.loc.fundExchangeBankTransferWireTimeframe,
                style: theme.textTheme.headlineSmall,
              ),
              const Gap(24.0),
              if (failedToLoadFundingDetails ||
                  details is! WireFundingDetails?) ...[
                const FundExchangeDetailsErrorCard(),
                const Gap(24.0),
              ] else ...[
                FundExchangeDetail(
                  label: context.loc.fundExchangeLabelBeneficiaryName,
                  helpText: context.loc.fundExchangeHelpBeneficiaryName,
                  value: details?.beneficiaryName,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: context.loc.fundExchangeLabelTransferCode,
                  helpText: context.loc.fundExchangeHelpTransferCode,
                  value: details?.code,
                ),
                const Gap(16.0),
                InfoCard(
                  bgColor: theme.colorScheme.inverseSurface.withValues(
                    alpha: 0.1,
                  ),
                  tagColor: theme.colorScheme.secondary,
                  description: context.loc.fundExchangeInfoTransferCode,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: context.loc.fundExchangeLabelBankAccountDetails,
                  value: details?.bankAccountDetails,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: context.loc.fundExchangeLabelSwiftCode,
                  value: details?.swift,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: context.loc.fundExchangeLabelInstitutionNumber,
                  value: details?.institutionNumber,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: context.loc.fundExchangeLabelTransitNumber,
                  value: details?.transitNumber,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: context.loc.fundExchangeLabelRoutingNumber,
                  value: details?.routingNumber,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: context.loc.fundExchangeLabelBeneficiaryAddress,
                  value: details?.beneficiaryAddress,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: context.loc.fundExchangeLabelBankName,
                  value: details?.bankName,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: context.loc.fundExchangeLabelBankAddress,
                  value: details?.bankAddress,
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
