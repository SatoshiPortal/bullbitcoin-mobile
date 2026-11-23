import 'package:exchange/exchange.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_detail.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_details_error_card.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_done_bottom_navigation_bar.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullInfoCard, BullText, Gap, BullTypographyX;

class FundExchangeCrIbanCrcScreen extends StatelessWidget {
  const FundExchangeCrIbanCrcScreen({super.key});

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
                context.loc.fundExchangeCrIbanCrcTitle,
                style: context.bullType.headline,
              ),
              const Gap(16.0),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: context.loc.fundExchangeCrIbanCrcDescription,
                      style: context.bullType.subtitle.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    TextSpan(
                      text: context.loc.fundExchangeCrIbanCrcDescriptionBold,
                      style: context.bullType.subtitle
                          .copyWith(fontWeight: FontWeight.w400)
                          .copyWith(fontWeight: .bold),
                    ),
                    TextSpan(
                      text: context.loc.fundExchangeCrIbanCrcDescriptionEnd,
                      style: context.bullType.subtitle.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
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
                BullInfoCard(
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
