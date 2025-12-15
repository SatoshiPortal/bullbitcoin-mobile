import 'package:bb_mobile/core_deprecated/exchange/domain/entity/funding_details.dart';
import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:bb_mobile/core_deprecated/widgets/text/text.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_detail.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_details_error_card.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_done_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class FundExchangeSinpeScreen extends StatelessWidget {
  const FundExchangeSinpeScreen({super.key});

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
                context.loc.fundExchangeSinpeTitle,
                style: theme.textTheme.displaySmall,
              ),
              const Gap(16.0),
              RichText(
                text: TextSpan(
                  text: context.loc.fundExchangeSinpeDescription,
                  style: theme.textTheme.headlineSmall,
                  children: [
                    TextSpan(
                      text: context.loc.fundExchangeSinpeDescriptionBold,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: .bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(24.0),
              Text(
                context.loc.fundExchangeSinpeAddedToBalance,
                style: theme.textTheme.headlineSmall,
              ),
              const Gap(24.0),
              Container(
                clipBehavior: .hardEdge,
                decoration: BoxDecoration(
                  color: context.appColors.inverseSurface.withValues(
                    alpha: 0.1,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: .stretch,
                    mainAxisAlignment: .center,
                    children: [
                      Container(
                        width: 4,
                        color: context.appColors.inverseSurface,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            crossAxisAlignment: .start,
                            mainAxisAlignment: .center,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 24,
                                color: context.appColors.inverseSurface,
                              ),
                              const Gap(12),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    text:
                                        context
                                            .loc
                                            .fundExchangeSinpeWarningNoBitcoin,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: context.appColors.secondary,
                                      fontWeight: .bold,
                                    ),
                                    children: [
                                      TextSpan(
                                        text:
                                            context
                                                .loc
                                                .fundExchangeSinpeWarningNoBitcoinDescription,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color:
                                                  context.appColors.secondary,
                                              fontWeight: .normal,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Gap(24.0),
              if (failedToLoadFundingDetails ||
                  details is! SinpeFundingDetails?) ...[
                const FundExchangeDetailsErrorCard(),
                const Gap(24.0),
              ] else ...[
                FundExchangeDetail(
                  label: context.loc.fundExchangeSinpeLabelPhone,
                  value: details?.number,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: context.loc.fundExchangeSinpeLabelRecipientName,
                  value: details?.beneficiaryName,
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
