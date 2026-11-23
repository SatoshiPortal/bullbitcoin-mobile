import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/funding/presentation/fund_exchange_bloc.dart';
import 'package:bull_exchange/src/funding/ui/widgets/fund_exchange_detail.dart';
import 'package:bull_exchange/src/funding/ui/widgets/fund_exchange_details_error_card.dart';
import 'package:bull_exchange/src/funding/ui/widgets/fund_exchange_done_bottom_navigation_bar.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show BullText, Gap, BullTypographyX;

class FundExchangeArsBankTransferScreen extends StatelessWidget {
  const FundExchangeArsBankTransferScreen({super.key});

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
                context.loc.fundExchangeArsBankTransferTitle,
                style: context.bullType.headline,
              ),
              const Gap(16.0),
              BullText(
                context.loc.fundExchangeArsBankTransferDescription,
                style: context.bullType.subtitle.copyWith(
                  fontWeight: FontWeight.w400,
                ),
              ),
              const Gap(24.0),
              if (failedToLoadFundingDetails ||
                  details is! ArsBankTransferFundingDetails?) ...[
                const FundExchangeDetailsErrorCard(),
                const Gap(24.0),
              ] else ...[
                FundExchangeDetail(
                  label: context.loc.fundExchangeLabelRecipientNameArs,
                  value: details?.beneficiaryName,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: context.loc.fundExchangeLabelCvu,
                  value: details?.cvu,
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
