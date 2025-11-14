import 'package:bb_mobile/core/exchange/domain/entity/funding_details.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_details_error_card.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_done_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:qr_flutter/qr_flutter.dart';

class FundExchangeCanadaPostScreen extends StatelessWidget {
  const FundExchangeCanadaPostScreen({super.key});

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
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BBText(
                context.loc.fundExchangeCanadaPostTitle,
                style: theme.textTheme.displaySmall,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(step, style: const TextStyle(fontSize: 14)),
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
                      BBText(
                        context.loc.fundExchangeCanadaPostQrCodeLabel,
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const Gap(8.0),
                      if (details?.code == null)
                        const LoadingBoxContent(height: 250.0, width: 250.0)
                      else
                        QrImageView(size: 250, data: details!.code),
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
