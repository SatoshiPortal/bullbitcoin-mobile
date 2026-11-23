import 'package:bull_ui/bull_ui.dart' show BullInfoCard;
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/fund_exchange_failure_l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FundExchangeDetailsErrorCard extends StatelessWidget {
  const FundExchangeDetailsErrorCard({super.key});

  @override
  Widget build(BuildContext context) {
    final failure = context.select(
      (FundExchangeBloc bloc) => bloc.state.getFundingDetailsFailure,
    );

    return BullInfoCard(
      title: failure?.toTranslatedTitle(context),
      // This card only shows a failed details load, so its catch-all can be
      // more specific than the shared generic message.
      description: switch (failure) {
        null || FundExchangeUnexpectedFailure() =>
          context.loc.fundExchangeErrorLoadingDetails,
        final failure => failure.toTranslated(context),
      },
      bgColor: context.appColors.error.withValues(alpha: 0.1),
      tagColor: context.appColors.primary,
    );
  }
}
