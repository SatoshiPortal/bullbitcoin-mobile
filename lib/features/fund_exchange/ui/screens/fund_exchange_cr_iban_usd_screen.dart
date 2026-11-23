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
    show BullInfoCard, BullText, Gap, BullTypographyX;

class FundExchangeCrIbanUsdScreen extends StatelessWidget {
  const FundExchangeCrIbanUsdScreen({super.key});

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
                context.loc.fundExchangeCrIbanUsdTitle,
                style: context.bullType.headline,
              ),
              const Gap(16.0),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: context.loc.fundExchangeCrIbanUsdDescription,
                      style: context.bullType.subtitle.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    TextSpan(
                      text: context.loc.fundExchangeCrIbanUsdDescriptionBold,
                      style: context.bullType.subtitle
                          .copyWith(fontWeight: FontWeight.w400)
                          .copyWith(fontWeight: .bold),
                    ),
                    TextSpan(
                      text: context.loc.fundExchangeCrIbanUsdDescriptionEnd,
                      style: context.bullType.subtitle.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(24.0),
              if (failedToLoadFundingDetails ||
                  details is! CrIbanUsdFundingDetails?) ...[
                const FundExchangeDetailsErrorCard(),
                const Gap(24.0),
              ] else ...[
                FundExchangeDetail(
                  label: context.loc.fundExchangeCrIbanUsdLabelIban,
                  value: details?.iban,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label:
                      context.loc.fundExchangeCrIbanUsdLabelPaymentDescription,
                  value: details?.code,
                  helpText:
                      context.loc.fundExchangeCrIbanUsdPaymentDescriptionHelp,
                ),
                const Gap(16.0),
                BullInfoCard(
                  description:
                      context.loc.fundExchangeCrIbanUsdTransferCodeWarning,
                  bgColor: context.appColors.inverseSurface.withValues(
                    alpha: 0.1,
                  ),
                  tagColor: context.appColors.secondary,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: context.loc.fundExchangeCrIbanUsdLabelRecipientName,
                  value: details?.beneficiaryName,
                  helpText: context.loc.fundExchangeCrIbanUsdRecipientNameHelp,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: context.loc.fundExchangeCrIbanUsdLabelCedulaJuridica,
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
