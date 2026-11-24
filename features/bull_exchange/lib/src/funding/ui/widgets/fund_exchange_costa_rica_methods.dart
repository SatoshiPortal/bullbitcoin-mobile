import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/funding/ui/widgets/fund_exchange_method_list_tile.dart';
import 'package:bull_exchange/src/funding/presentation/fund_exchange_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;

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
