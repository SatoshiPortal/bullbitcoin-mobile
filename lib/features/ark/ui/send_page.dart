/*import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/dialpad/dial_pad.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/price_input/balance_row.dart';
import 'package:bb_mobile/core/widgets/price_input/price_input.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/ark/presentation/cubit.dart';
import 'package:bb_mobile/features/ark/presentation/state.dart';
import 'package:bb_mobile/features/ark/ui/collaborative_redeem_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SendPage extends StatefulWidget {
  const SendPage({super.key});

  @override
  State<SendPage> createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  late final _inputCurrencyCode;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<ArkCubit>();
    _inputCurrencyCode = cubit.state.currencyCode;
  }


  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ArkCubit, ArkState>(
      listener: (context, state) {
        if (state.error != null) {
          SnackBarUtils.showSnackBar(context, state.error!.message);
          context.read<ArkCubit>().clearError();
        }
      },
      builder: (context, state) {
        final cubit = context.read<ArkCubit>();
        final amount = int.tryParse(_amountController.text);
        final isValidAmount = amount != null;

        final fiatAmount = FormatAmount.fiat(
          ConvertAmount.satsToFiat(amount ?? 0, state.exchangeRate),
          state.currencyCode,
        );

        return Scaffold(
          appBar: AppBar(
            title: BBText('Send', style: context.font.headlineMedium),
          ),
          body: SafeArea(
            child: ScrollableColumn(
              children: [
                Column(
                  children: [
                    BBText(
                      "Recipient's address",
                      style: context.font.bodyMedium,
                    ),
                    BBInputText(
                      onlyPaste: true,
                      onChanged: cubit.updateSendAddress,
                      value: state.sendAddress.address,
                      hint: 'ark1qp9wsjfpsj5v5ex022v6…',
                      hintStyle: context.font.bodyLarge?.copyWith(
                        color: context.colour.surfaceContainer,
                      ),
                      maxLines: 1,
                      rightIcon: Icon(
                        Icons.paste_sharp,
                        color: context.colour.secondary,
                        size: 20,
                      ),
                      onRightTap: () {
                        Clipboard.getData(Clipboard.kTextPlain).then((value) {
                          final clipboard = value?.text;
                          if (clipboard == null) return;
                          cubit.updateSendAddress(clipboard);
                        });
                      },
                    ),
                  ],
                ),
                Column(
                  children: [
                    PriceInput(
                      currency: 'sats',
                      amountEquivalent: fiatAmount,
                      availableCurrencies: state.fiatCurrencyCodes,
                      amountController: _amountController,
                      onNoteChanged: null,
                      onCurrencyChanged: cubit.onSendCurrencyCodeChanged,
                      error: null,
                      focusNode: null,
                      readOnly: true,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: BalanceRow(
                        title: 'Confirmed Balance',
                        balance: state.confirmedBalance.toString(),
                        currencyCode: 'sats',
                        onMaxPressed:
                            () => _updateAmount(
                              state.confirmedBalance.toString(),
                              state.confirmedBalance,
                            ),
                        walletLabel: null,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: BalanceRow(
                        title: 'Pending Balance    ',
                        balance: state.pendingBalance.toString(),
                        currencyCode: 'sats',
                        onMaxPressed: null,
                        walletLabel: null,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    DialPad(
                      onNumberPressed: (pressed) {
                        if (pressed == '.') return; // Sats only
                        _updateAmount(
                          amountController.text + pressed,
                          state.confirmedBalance,
                        );
                      },
                      onBackspacePressed: () {
                        final amount = amountController.text;
                        if (amount.isEmpty) return;

                        final newAmount = amount.substring(
                          0,
                          amount.length - 1,
                        );
                        _updateAmount(newAmount, state.confirmedBalance);
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: BBButton.big(
                        label: 'Confirm',
                        onPressed: () async {
                          final hasValidAddress = await state.hasValidAddress;
                          if (amount == null || !hasValidAddress) return;

                          try {
                            switch (state.sendAddress.type) {
                              case null:
                                return;
                              case AddressType.btc:
                                if (!context.mounted) return;
                                await CollaborativeRedeemBottomSheet.show(
                                  context,
                                  cubit,
                                  amount,
                                );
                              case AddressType.ark:
                                await cubit.onSendConfirmed(amount);
                            }
                            if (context.mounted) context.pop();
                          } catch (e) {
                            if (!context.mounted) return;
                            SnackBarUtils.showSnackBar(context, e.toString());
                          }
                        },
                        disabled: !isValidAmount,
                        bgColor: context.colour.primary,
                        textColor: context.colour.onPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
*/
