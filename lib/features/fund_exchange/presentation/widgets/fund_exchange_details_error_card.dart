import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';

class FundExchangeDetailsErrorCard extends StatelessWidget {
  const FundExchangeDetailsErrorCard({super.key});

  @override
  Widget build(BuildContext context) {
    final error = context.select(
      (FundExchangeBloc bloc) => bloc.state.getExchangeFundingDetailsException,
    );

    return BullInfoCard(
      title: error?.displayTitle(context.loc),
      description:
          error?.displayMessage(context.loc) ??
          context.loc.fundExchangeErrorLoadingDetails,
      bgColor: context.bull.error.withValues(alpha: 0.1),
      tagColor: context.bull.primary,
    );
  }
}
