import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_details.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_details_error_card.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_done_bottom_navigation_bar.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullShimmerBox, BullText, BullQrCode, Gap, BullTypographyX;

class FundExchangeCanadaPostScreen extends StatelessWidget {
  const FundExchangeCanadaPostScreen({super.key});

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
                context.loc.fundExchangeCanadaPostTitle,
                style: context.bullType.headline,
              ),
              const Gap(16.0),
              ...[
                context.loc.fundExchangeCanadaPostStep1,
                context.loc.fundExchangeCanadaPostStep2,
                context.loc.fundExchangeCanadaPostStep3,
                context.loc.fundExchangeCanadaPostStep4,
                context.loc.fundExchangeCanadaPostStep5,
                context.loc.fundExchangeCanadaPostStep6,
                context.loc.fundExchangeCanadaPostStep7,
              ].map(
                (step) => Row(
                  crossAxisAlignment: .start,
                  children: [
                    Expanded(
                      child: BullText(step, style: context.bullType.body),
                    ),
                  ],
                ),
              ),
              const Gap(24.0),
              if (failedToLoadFundingDetails ||
                  details is! CanadaPostFundingDetails?) ...[
                const FundExchangeDetailsErrorCard(),
                const Gap(24.0),
              ] else ...[
                Center(
                  child: Column(
                    children: [
                      BullText(
                        context.loc.fundExchangeCanadaPostQrCodeLabel,
                        style: context.bullType.body,
                        textAlign: .center,
                      ),
                      const Gap(8.0),
                      BullQrCode(
                        data: details?.code ?? '',
                        size: 250,
                        semanticsLabel:
                            context.loc.fundExchangeCanadaPostQrCodeLabel,
                        errorBuilder: (_) => (details?.code.isEmpty ?? true)
                            ? const BullShimmerBox(height: 250, width: 250)
                            : const SizedBox.shrink(),
                      ),
                      const Gap(24.0),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: const FundExchangeDoneBottomNavigationBar(),
    );
  }
}
