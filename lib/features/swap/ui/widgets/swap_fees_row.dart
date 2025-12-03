import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SwapFeesRow extends StatelessWidget {
  const SwapFeesRow({super.key, required this.amountSat});

  final int amountSat;

  @override
  Widget build(BuildContext context) {
    final estimatedFeesSat = context.select(
      (TransferBloc bloc) => bloc.state.getSwapFeesSat(amountSat),
    );
    final bitcoinUnit = context.select(
      (TransferBloc bloc) => bloc.state.bitcoinUnit,
    );
    final estimatedFees =
        bitcoinUnit == BitcoinUnit.sats
            ? FormatAmount.sats(estimatedFeesSat)
            : FormatAmount.btc(ConvertAmount.satsToBtc(estimatedFeesSat));

    return Row(
      children: [
        Text(
          context.loc.swapTotalFees,
          style: context.font.labelLarge?.copyWith(
            color: context.colour.surface,
          ),
        ),
        const Gap(4),
        Text(estimatedFees, style: context.font.labelLarge),
      ],
    );
  }
}
