import 'package:primitives/primitives.dart'
    show BitcoinUnit, ConvertAmount, FormatAmount;
import 'package:bull_ui/app_theme.dart';
import 'package:swap_feature/src/swap_l10n.dart';
import 'package:swap_feature/src/presentation/transfer_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButtonSize, BullButton, BullSpacing, Gap, BullTypographyX;

class SwapBalanceRow extends StatelessWidget {
  const SwapBalanceRow({super.key});

  @override
  Widget build(BuildContext context) {
    final fromWallet = context.select(
      (TransferBloc bloc) => bloc.state.fromWallet,
    );
    final bitcoinUnit = context.select(
      (TransferBloc bloc) => bloc.state.bitcoinUnit,
    );
    final balanceSat = fromWallet?.balanceSat?.toInt();
    // Unknown while the wallets load; a failed load shows as the page error.
    final balance = balanceSat == null
        ? '…'
        : bitcoinUnit == BitcoinUnit.sats
        ? FormatAmount.sats(balanceSat)
        : FormatAmount.btc(ConvertAmount.satsToBtc(balanceSat));

    final maxAmountSat = context.select(
      (TransferBloc bloc) => bloc.state.maxAmountSat,
    );

    return Row(
      children: [
        Text(
          context.swapCopyForLocale.swapAvailableBalance,
          style: context.bullType.label.copyWith(
            color: context.appColors.secondary,
          ),
        ),
        const Gap(4),
        // A missing balance reads as a sentence: it wraps beside MAX rather
        // than running under it.
        Expanded(child: Text(balance, style: context.bullType.label)),
        const Gap(8),
        // Inset like the field actions above, so the black boxes line up.
        Padding(
          padding: const EdgeInsetsDirectional.only(end: BullSpacing.xs),
          child: BullButton.secondary(
            size: BullButtonSize.small,
            label: context.swapCopyForLocale.swapMaxButton,
            height: 48,
            width: 51,
            textStyle: context.bullType.label,
            onPressed: (maxAmountSat == null || maxAmountSat <= 0)
                ? null
                : () {
                    context.read<TransferBloc>().add(
                      const TransferEvent.maxSelected(),
                    );
                  },
          ),
        ),
      ],
    );
  }
}
