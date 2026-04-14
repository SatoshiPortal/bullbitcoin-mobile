import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/widgets/fund_exchange_method_list_tile.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class FundExchangeCostaRicaMethods extends StatelessWidget {
  const FundExchangeCostaRicaMethods({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        FundExchangeMethodListTile(
          title: context.loc.fundExchangeCostaRicaMethodSinpeTitle,
          subtitle: context.loc.fundExchangeCostaRicaMethodSinpeSubtitle,
          onTap: () {
            context.read<FundExchangeBloc>().add(
              const FundExchangeEvent.fundingDetailsRequested(
                fundingMethod: Sinpe(),
              ),
            );
          },
        ),
        const Gap(16.0),
        FundExchangeMethodListTile(
          title: context.loc.fundExchangeCostaRicaMethodIbanCrcTitle,
          subtitle: context.loc.fundExchangeCostaRicaMethodIbanCrcSubtitle,
          onTap: () {
            context.read<FundExchangeBloc>().add(
              const FundExchangeEvent.fundingDetailsRequested(
                fundingMethod: CrIbanCrc(),
              ),
            );
          },
        ),
        const Gap(16.0),
        FundExchangeMethodListTile(
          title: context.loc.fundExchangeCostaRicaMethodIbanUsdTitle,
          subtitle: context.loc.fundExchangeCostaRicaMethodIbanUsdSubtitle,
          onTap: () {
            context.read<FundExchangeBloc>().add(
              const FundExchangeEvent.fundingDetailsRequested(
                fundingMethod: CrIbanUsd(),
              ),
            );
          },
        ),
      ],
    );
  }
}
