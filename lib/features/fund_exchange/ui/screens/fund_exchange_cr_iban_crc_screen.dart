import 'package:bb_mobile/core_deprecated/exchange/domain/entity/funding_details.dart';
import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:bb_mobile/core_deprecated/widgets/cards/info_card.dart';
import 'package:bb_mobile/core_deprecated/widgets/text/text.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_detail.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_details_error_card.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_done_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class FundExchangeCrIbanCrcScreen extends StatelessWidget {
  const FundExchangeCrIbanCrcScreen({super.key});

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
            mainAxisAlignment: .center,
            crossAxisAlignment: .start,
            children: [
              BBText(
                context.loc.fundExchangeCrIbanCrcTitle,
                style: theme.textTheme.displaySmall,
              ),
              const Gap(16.0),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: context.loc.fundExchangeCrIbanCrcDescription,
                      style: theme.textTheme.headlineSmall,
                    ),
                    TextSpan(
                      text: context.loc.fundExchangeCrIbanCrcDescriptionBold,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: .bold,
                      ),
                    ),
                    TextSpan(
                      text: context.loc.fundExchangeCrIbanCrcDescriptionEnd,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
              const Gap(24.0),
              if (failedToLoadFundingDetails ||
                  details is! CrIbanCrcFundingDetails?) ...[
                const FundExchangeDetailsErrorCard(),
                const Gap(24.0),
              ] else ...[
                FundExchangeDetail(
                  label: context.loc.fundExchangeCrIbanCrcLabelIban,
                  value: details?.iban,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label:
                      context.loc.fundExchangeCrIbanCrcLabelPaymentDescription,
                  value: details?.code,
                  helpText:
                      context.loc.fundExchangeCrIbanCrcPaymentDescriptionHelp,
                ),
                const Gap(16.0),
                InfoCard(
                  description:
                      context.loc.fundExchangeCrIbanCrcTransferCodeWarning,
                  bgColor: context.appColors.inverseSurface.withValues(
                    alpha: 0.1,
                  ),
                  tagColor: context.appColors.secondary,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: context.loc.fundExchangeCrIbanCrcLabelRecipientName,
                  value: details?.beneficiaryName,
                  helpText: context.loc.fundExchangeCrIbanCrcRecipientNameHelp,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: context.loc.fundExchangeCrIbanCrcLabelCedulaJuridica,
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
