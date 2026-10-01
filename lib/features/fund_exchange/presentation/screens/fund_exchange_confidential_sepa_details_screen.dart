import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_details.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/widgets/fund_exchange_detail.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/widgets/fund_exchange_details_error_card.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/widgets/fund_exchange_done_bottom_navigation_bar.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FundExchangeConfidentialSepaDetailsScreen extends StatelessWidget {
  const FundExchangeConfidentialSepaDetailsScreen({super.key});

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
                context.loc.recipientsTypeConfidentialSepa,
                style: theme.textTheme.displaySmall,
              ),
              const Gap(16.0),
              BBText(
                context.loc.fundExchangeConfidentialSepaDescription,
                style: theme.textTheme.headlineSmall,
              ),
              const Gap(24.0),
              if (failedToLoadFundingDetails ||
                  details is! ConfidentialSepaFundingDetails?) ...[
                const FundExchangeDetailsErrorCard(),
                const Gap(24.0),
              ] else ...[
                InfoCard(
                  title: context.loc.fundExchangeConfidentialSepaNameMatchTitle,
                  description:
                      context.loc.fundExchangeConfidentialSepaNameMatchWarning,
                  tagColor: context.appColors.success,
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
                  value: details?.recipientName,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: context.loc.fundExchangeLabelBankAddress,
                  value: details?.bankAddress,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: context.loc.fundExchangeLabelBankCountry,
                  value: details?.bankAccountCountry,
                  copyable: false,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: context.loc.fundExchangeLabelBicCode,
                  value: details?.bic,
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
