import 'package:exchange/exchange.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_detail.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_details_error_card.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_done_bottom_navigation_bar.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullText, BullShapesX, Gap, BullTypographyX;

class FundExchangeSinpeScreen extends StatelessWidget {
  const FundExchangeSinpeScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
              BullText(
                context.loc.fundExchangeSinpeTitle,
                style: context.bullType.headline,
              ),
              const Gap(16.0),
              RichText(
                text: TextSpan(
                  text: context.loc.fundExchangeSinpeDescription,
                  style: context.bullType.subtitle.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                  children: [
                    TextSpan(
                      text: context.loc.fundExchangeSinpeDescriptionBold,
                      style: context.bullType.subtitle
                          .copyWith(fontWeight: FontWeight.w400)
                          .copyWith(fontWeight: .bold),
                    ),
                  ],
                ),
              ),
              const Gap(24.0),
              BullText(
                context.loc.fundExchangeSinpeAddedToBalance,
                style: context.bullType.subtitle.copyWith(
                  fontWeight: FontWeight.w400,
                ),
              ),
              const Gap(24.0),
              Container(
                clipBehavior: .hardEdge,
                decoration: BoxDecoration(
                  color: context.appColors.inverseSurface.withValues(
                    alpha: 0.1,
                  ),
                  borderRadius: BorderRadius.circular(context.bullShapes.card),
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
                                    text: context
                                        .loc
                                        .fundExchangeSinpeWarningNoBitcoin,
                                    style: context.bullType.body.copyWith(
                                      color: context.appColors.secondary,
                                      fontWeight: .bold,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: context
                                            .loc
                                            .fundExchangeSinpeWarningNoBitcoinDescription,
                                        style: context.bullType.body.copyWith(
                                          color: context.appColors.secondary,
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
