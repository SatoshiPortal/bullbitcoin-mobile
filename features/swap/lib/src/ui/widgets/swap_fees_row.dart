import 'package:primitives/primitives.dart'
    show BitcoinUnit, ConvertAmount, FormatAmount;
import 'package:bull_ui/app_theme.dart';
import 'package:swap_feature/src/swap_l10n.dart';
import 'package:swap_feature/src/presentation/transfer_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullFiatEquivalent, Gap, BullTypographyX;

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
    final estimatedFeesFiat = context.select(
      (TransferBloc bloc) => bloc.state.formattedFiatOf(estimatedFeesSat),
    );
    final estimatedFees = bitcoinUnit == BitcoinUnit.sats
        ? FormatAmount.sats(estimatedFeesSat)
        : FormatAmount.btc(ConvertAmount.satsToBtc(estimatedFeesSat));

    return Row(
      children: [
        Text(
          context.swapCopyForLocale.swapTotalFees,
          style: context.bullType.label.copyWith(
            color: context.appColors.surface,
          ),
        ),
        const Gap(4),
        Text(estimatedFees, style: context.bullType.label),
        const Gap(4),
        BullFiatEquivalent(estimatedFeesFiat, textAlign: TextAlign.start),
      ],
    );
  }
}
