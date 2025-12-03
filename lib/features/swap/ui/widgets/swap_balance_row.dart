import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

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
    final balanceSat = fromWallet?.balanceSat.toInt() ?? 0;
    final balance =
        bitcoinUnit == BitcoinUnit.sats
            ? FormatAmount.sats(balanceSat)
            : FormatAmount.btc(ConvertAmount.satsToBtc(balanceSat));

    final maxAmountSat = context.select(
      (TransferBloc bloc) => bloc.state.maxAmountSat,
    );
    final maxAmount =
        bitcoinUnit == BitcoinUnit.sats
            ? maxAmountSat
            : ConvertAmount.satsToBtc(maxAmountSat ?? 0);

    return Row(
      children: [
        Text(
          context.loc.swapAvailableBalance,
          style: context.font.labelLarge?.copyWith(
            color: context.appColors.surface,
          ),
        ),
        const Gap(4),
        Text(balance, style: context.font.labelLarge),
        const Spacer(),
        BBButton.small(
          label: context.loc.swapMaxButton,
          height: 30,
          width: 51,
          bgColor: context.appColors.secondaryFixedDim,
          textColor: context.appColors.secondary,
          textStyle: context.font.labelLarge,
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
