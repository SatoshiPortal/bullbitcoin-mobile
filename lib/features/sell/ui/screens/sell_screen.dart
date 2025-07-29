import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/sell/presentation/bloc/sell_bloc.dart';
import 'package:bb_mobile/features/sell/ui/widgets/sell_amount_currency_dropdown.dart';
import 'package:bb_mobile/features/sell/ui/widgets/sell_amount_input_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SellScreen extends StatefulWidget {
  const SellScreen({super.key});

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController = TextEditingController();
  bool _isFiatCurrencyInput = true;
  FiatCurrency? _fiatCurrency;
  int _amountSat = 0;
  double _amountFiat = 0.0;

  @override
  void initState() {
    _amountController.addListener(() {
      final convertedAmounts = _convertAmountInput();
      setState(() {
        _amountSat = convertedAmounts.amountSat;
        _amountFiat = convertedAmounts.amountFiat;
      });
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Adding the leading icon button here manually since we are in the first
        // route of a shellroute and so no back button is provided by default.
        leading:
            context.canPop()
                ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    context.pop();
                  },
                )
                : null,
        title: const Text('Sell Bitcoin'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ScrollableColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SellAmountInputField(
                amountController: _amountController,
                amountSat: _amountSat,
                amountFiat: _amountFiat,
                fiatCurrency: _fiatCurrency,
                isFiatCurrencyInput: _isFiatCurrencyInput,
                onIsFiatCurrencyInputChanged: (bool isFiat) {
                  setState(() {
                    _isFiatCurrencyInput = isFiat;
                  });
                },
              ),
              const Gap(16.0),
              SellAmountCurrencyDropdown(
                selectedCurrency: _fiatCurrency?.code,
                onCurrencyChanged: (String currencyCode) {
                  setState(() {
                    _fiatCurrency = FiatCurrency.fromCode(currencyCode);
                  });
                },
              ),
              const Spacer(),
              _ConfirmationButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final sellBloc = context.read<SellBloc>();
                    final sellState = sellBloc.state;
                    sellBloc.add(
                      SellEvent.confirmAmount(
                        amountInput: _amountController.text,
                        isFiatCurrencyInput: _isFiatCurrencyInput,
                        fiatCurrency:
                            _fiatCurrency ??
                            ((sellState is SellAmountState)
                                ? FiatCurrency.fromCode(
                                  sellState.userSummary.currency ?? 'CAD',
                                )
                                : sellState is SellPayoutMethodState
                                ? sellState.fiatCurrency
                                : FiatCurrency.cad),
                      ),
                    );
                  }
                },
              ),
              const Gap(16.0),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  ({double amountFiat, int amountSat}) _convertAmountInput() {
    final sellState = context.read<SellBloc>().state;
    final bitcoinUnit =
        sellState is SellAmountState
            ? sellState.bitcoinUnit
            : sellState is SellPayoutMethodState
            ? sellState.bitcoinUnit
            : BitcoinUnit.btc;
    double amountFiat;
    int amountSat;
    if (_isFiatCurrencyInput) {
      amountFiat = double.tryParse(_amountController.text) ?? 0.0;
      final amountBtc =
          amountFiat / 1; // TODO: Change for actual user conversion rate
      amountSat = ConvertAmount.btcToSats(amountBtc);
    } else {
      if (bitcoinUnit == BitcoinUnit.sats) {
        amountSat = int.tryParse(_amountController.text) ?? 0;
        final amountBtc = ConvertAmount.satsToBtc(amountSat);
        amountFiat =
            amountBtc * 1; // TODO: Change for actual user conversion rate
      } else {
        final amountBtc = double.tryParse(_amountController.text) ?? 0.0;
        amountSat = ConvertAmount.btcToSats(amountBtc);
        amountFiat =
            amountBtc * 1; // TODO: Change for actual user conversion rate
      }
    }

    return (amountFiat: amountFiat, amountSat: amountSat);
  }
}

class _ConfirmationButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ConfirmationButton({required this.onPressed}) : super();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SellBloc, SellState, bool>(
      selector: (state) => state is SellAmountState && state.isConfirmingAmount,
      builder: (context, isConfirmingAmount) {
        return Column(
          children: [
            if (isConfirmingAmount) ...[
              const CircularProgressIndicator(),
              const Gap(24.0),
            ],
            BBButton.big(
              label: 'Continue',
              disabled: isConfirmingAmount,
              onPressed: onPressed,
              bgColor: context.colour.secondary,
              textColor: context.colour.onSecondary,
            ),
          ],
        );
      },
    );
  }
}
