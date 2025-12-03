import 'package:bb_mobile/core/exchange/domain/entity/funding_details.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
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

class FundExchangeRegularSepaScreen extends StatelessWidget {
  const FundExchangeRegularSepaScreen({super.key});

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
                context.loc.fundExchangeSepaTitle,
                style: theme.textTheme.displaySmall,
              ),
              const Gap(16.0),
              RichText(
                text: TextSpan(
                  text: context.loc.fundExchangeSepaDescription,
                  style: theme.textTheme.headlineSmall,
                  children: [
                    TextSpan(
                      text: context.loc.fundExchangeSepaDescriptionExactly,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: .bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(24.0),
              if (failedToLoadFundingDetails ||
                  details is! RegularSepaFundingDetails?) ...[
                const FundExchangeDetailsErrorCard(),
                const Gap(24.0),
              ] else ...[
                InfoCard(
                  description: context.loc.fundExchangeRegularSepaInfo,
                  tagColor: context.appColors.secondary,
                  bgColor: context.appColors.inverseSurface.withValues(
                    alpha: 0.1,
                  ),
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: context.loc.fundExchangeLabelIban,
                  value: details?.iban,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: context.loc.fundExchangeLabelRecipientName,
                  value: details?.beneficiaryName,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: context.loc.fundExchangeLabelTransferCode,
                  value: details?.code,
                ),
                const Gap(16.0),
                InfoCard(
                  bgColor: context.appColors.inverseSurface.withValues(
                    alpha: 0.1,
                  ),
                  tagColor: context.appColors.secondary,
                  description: context.loc.fundExchangeInfoPaymentDescription,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: context.loc.fundExchangeLabelBankCountry,
                  value: details?.bankCountry,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: context.loc.fundExchangeLabelBicCode,
                  value: details?.bic,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: context.loc.fundExchangeLabelRecipientAddress,
                  value: details?.beneficiaryAddress,
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
