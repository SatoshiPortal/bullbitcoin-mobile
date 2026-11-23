import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:exchange/exchange.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_details_error_card.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_done_bottom_navigation_bar.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_error_text.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/fund_exchange_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullText, BullButton, Gap, BullTypographyX;

class FundExchangeCopBankTransferScreen extends StatelessWidget {
  const FundExchangeCopBankTransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final details = context.select(
      (FundExchangeBloc bloc) => bloc.state.fundingDetails,
    );
    final failedToLoadFundingDetails = context.select(
      (FundExchangeBloc bloc) => bloc.state.failedToLoadFundingDetails,
    );
    final openPaymentLinkFailure = context.select(
      (FundExchangeBloc bloc) => bloc.state.openPaymentLinkFailure,
    );
    final isOpeningPaymentLink = context.select(
      (FundExchangeBloc bloc) => bloc.state.isOpeningPaymentLink,
    );
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.fundExchangeTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (failedToLoadFundingDetails ||
                    details is! CopBankTransferFundingDetails) ...[
                  const FundExchangeDetailsErrorCard(),
                  const Gap(24.0),
                ] else ...[
                  BullText(
                    context.loc.fundExchangeCopRedirectMessage,
                    style: context.bullType.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Gap(24.0),
                  BullButton.primary(
                    label: context.loc.fundExchangeCopOpenPaymentLink,
                    iconData: Icons.open_in_new,
                    // Disabled while a launch is in flight, so a double tap
                    // cannot open the payment page twice.
                    onPressed: (isOpeningPaymentLink)
                        ? null
                        : () => context.read<FundExchangeBloc>().add(
                            FundExchangeEvent.paymentLinkOpenRequested(
                              paymentLink: details.paymentLink,
                            ),
                          ),
                  ),
                  if (openPaymentLinkFailure != null) ...[
                    const Gap(16.0),
                    FundExchangeErrorText(failure: openPaymentLinkFailure),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const FundExchangeDoneBottomNavigationBar(),
    );
  }
}
