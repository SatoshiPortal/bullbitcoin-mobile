import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/frameworks/ui/widgets/fund_exchange_method_list_tile.dart';
import 'package:bb_mobile/features/fund_exchange/interface_adapters/presentation/bloc/fund_exchange_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class FundExchangeEuropeMethods extends StatelessWidget {
  const FundExchangeEuropeMethods({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
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
