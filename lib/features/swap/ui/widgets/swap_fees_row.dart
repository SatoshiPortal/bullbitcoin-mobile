import 'package:primitives/primitives.dart'
    show BitcoinUnit, ConvertAmount, FormatAmount;
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap, BullTypographyX;

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
    final estimatedFees = bitcoinUnit == BitcoinUnit.sats
        ? FormatAmount.sats(estimatedFeesSat)
        : FormatAmount.btc(ConvertAmount.satsToBtc(estimatedFeesSat));

    return Row(
      children: [
        Text(
          context.loc.swapTotalFees,
          style: context.bullType.label.copyWith(
            color: context.appColors.surface,
          ),
        ),
        const Gap(4),
        Text(estimatedFees, style: context.bullType.label),
      ],
    );
  }
}
