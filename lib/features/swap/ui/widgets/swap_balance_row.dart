import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
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
            ? balanceSat
            : ConvertAmount.satsToBtc(balanceSat);
    final displayFromCurrencyCode = context.select(
      (TransferBloc bloc) => bloc.state.displayFromCurrencyCode,
    );
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
          'Available balance',
          style: context.font.labelLarge?.copyWith(
            color: context.colour.surface,
          ),
        ),
        const Gap(4),
        Text(
          '$balance $displayFromCurrencyCode',
          style: context.font.labelLarge,
        ),
        const Spacer(),
        BBButton.small(
          label: 'MAX',
          height: 30,
          width: 51,
          bgColor: context.colour.secondaryFixedDim,
          textColor: context.colour.secondary,
          textStyle: context.font.labelLarge,
          disabled: maxAmountSat == null || maxAmountSat <= 0,
          onPressed: () {
            amountController.text = maxAmount.toString();
          },
        ),
      ],
    );
  }
}
