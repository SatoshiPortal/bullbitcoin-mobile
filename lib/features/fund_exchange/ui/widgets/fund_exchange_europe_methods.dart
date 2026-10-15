import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/fund_exchange_router.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_method_list_tile.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/fund_exchange_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;

class FundExchangeEuropeMethods extends StatelessWidget {
  const FundExchangeEuropeMethods({super.key});

  @override
  Widget build(BuildContext context) {
    final isConfidentialSepaAvailable = context.select(
      (FundExchangeBloc bloc) => bloc.state.isConfidentialSepaAvailable,
    );
    return Column(
      crossAxisAlignment: .start,
      children: [
        if (isConfidentialSepaAvailable) ...[
          FundExchangeMethodListTile(
            title: context.loc.fundExchangeMethodConfidentialSepa,
            subtitle: context.loc.fundExchangeMethodConfidentialSepaSubtitle,
            onTap: () => context.pushNamed(
              FundExchangeRoute.fundExchangeConfidentialSepa.name,
              extra: context.read<FundExchangeBloc>(),
            ),
          ),
          const Gap(16.0),
        ],
        FundExchangeMethodListTile(
          title: context.loc.fundExchangeMethodInstantSepa,
          subtitle: context.loc.fundExchangeMethodInstantSepaSubtitle,
          onTap: () {
            context.read<FundExchangeBloc>().add(
              const FundExchangeEvent.fundingDetailsRequested(
                fundingMethod: InstantSepa(),
              ),
            );
          },
        ),
        const Gap(16.0),
        FundExchangeMethodListTile(
          title: context.loc.fundExchangeMethodRegularSepa,
          subtitle: context.loc.fundExchangeMethodRegularSepaSubtitle,
          onTap: () {
            context.read<FundExchangeBloc>().add(
              const FundExchangeEvent.fundingDetailsRequested(
                fundingMethod: RegularSepa(),
              ),
            );
          },
        ),
      ],
    );
  }
}
