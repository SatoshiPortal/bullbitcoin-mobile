import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, Gap, BullTypographyX;

class SwapBalanceRow extends StatelessWidget {
  const SwapBalanceRow({super.key, required this.amountController});

  final TextEditingController amountController;

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
        ? context.loc.walletLoadFailed
        : bitcoinUnit == BitcoinUnit.sats
        ? FormatAmount.sats(balanceSat)
        : FormatAmount.btc(ConvertAmount.satsToBtc(balanceSat));

    final maxAmountSat = context.select(
      (TransferBloc bloc) => bloc.state.maxAmountSat,
    );
    final maxAmount = bitcoinUnit == BitcoinUnit.sats
        ? maxAmountSat
        : ConvertAmount.satsToBtc(maxAmountSat ?? 0);

    return Row(
      children: [
        Text(
          context.loc.swapAvailableBalance,
          style: context.bullType.label.copyWith(
            color: context.appColors.secondary,
          ),
        ),
        const Gap(4),
        Text(balance, style: context.bullType.label),
        const Spacer(),
        BullButton.small(
          label: context.loc.swapMaxButton,
          height: 30,
          width: 51,
          bgColor: context.appColors.secondaryFixedDim,
          textColor: context.appColors.secondary,
          textStyle: context.bullType.label,
          disabled: maxAmountSat == null || maxAmountSat <= 0,
          onPressed: () {
            context.read<TransferBloc>().add(
              const TransferEvent.receiveExactAmountToggled(false),
            );
            amountController.text = maxAmount.toString();
          },
        ),
      ],
    );
  }
}
