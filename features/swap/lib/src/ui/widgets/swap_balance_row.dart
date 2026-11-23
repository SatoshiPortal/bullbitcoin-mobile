import 'package:primitives/primitives.dart'
    show BitcoinUnit, ConvertAmount, FormatAmount;
import 'package:bull_ui/app_theme.dart';
import 'package:swap_feature/src/swap_l10n.dart';
import 'package:swap_feature/src/presentation/transfer_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButtonSize, BullButton, Gap, BullTypographyX;

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
    final balance = balanceSat == null
        ? context.swapCopyForLocale.walletLoadFailed
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
        Text(balance, style: context.bullType.label),
        const Spacer(),
        BullButton.secondary(
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
      ],
    );
  }
}
