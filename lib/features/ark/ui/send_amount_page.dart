import 'package:bb_mobile/core_deprecated/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:bb_mobile/core_deprecated/widgets/buttons/button.dart';
import 'package:bb_mobile/core_deprecated/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core_deprecated/widgets/price_input/balance_row.dart';
import 'package:bb_mobile/core_deprecated/widgets/price_input/price_input.dart';
import 'package:bb_mobile/core_deprecated/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/ark/presentation/cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SendAmountPage extends StatefulWidget {
  const SendAmountPage({
    super.key,
    this.prefilledAmount,
    this.prefilledCurrencyCode,
  });

  final String? prefilledAmount;
  final String? prefilledCurrencyCode;

  @override
  State<SendAmountPage> createState() => _SendAmountPageState();
}

class _SendAmountPageState extends State<SendAmountPage> {
  //final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late String _currencyCode;
  late final List<String> _availableCurrencies;
  late String _equivalentAmount;
  late bool _isLoading;
  late BitcoinUnit _preferredBitcoinUnit;
  String? _error;
  int? _maxSpendableSat;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledAmount != null) {
      _controller.text = widget.prefilledAmount!;
    }
    _isLoading = context.read<ArkCubit>().state.isLoading;
    _currencyCode = context.read<ArkCubit>().state.currencyCode!;
    _availableCurrencies = context.read<ArkCubit>().state.inputCurrencyCodes;
    _equivalentAmount =
        '0 ${context.read<ArkCubit>().state.equivalentCurrencyCode}';
    _maxSpendableSat = context.read<ArkCubit>().state.arkBalance?.total;
    _preferredBitcoinUnit = context.read<ArkCubit>().state.preferredBitcoinUnit;
    if (widget.prefilledCurrencyCode != null) {
      context.read<ArkCubit>().onSendCurrencyCodeChanged(
        widget.prefilledCurrencyCode!,
      );
    }

    context.read<ArkCubit>().stream.listen((state) {
      if (state.isLoading != _isLoading) {
        setState(() {
          _isLoading = state.isLoading;
        });
      }
      // Make sure the currency and so exchange rate is updated in the Cubit
      //  first before updating the local currency code. This is to avoid
      //  having a mismatch between the currency and exchange rate if something
      //  goes wrong in the Cubit or just because of race conditions.
      if (state.currencyCode != _currencyCode) {
        setState(() {
          _currencyCode = state.currencyCode!;
          _equivalentAmount = _calculateEquivalentAmount();
        });
      }

      if (state.error != null) {
        setState(() {
          _error = state.error!.message;
        });
      } else {
        setState(() {
          _error = null;
        });
      }
    });

    _controller.addListener(() {
      // Calculate equivalent amount when input changes
      setState(() {
        _equivalentAmount = _calculateEquivalentAmount();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onCurrencyCodeChanged(String? newCode) {
    if (newCode != null && newCode != _currencyCode) {
      context.read<ArkCubit>().onSendCurrencyCodeChanged(newCode);
      // Clear the amount input when changing currency
      _controller.text = '';
    }
  }

  void _submit() {
    // TODO: use a text form field in price input and validate
    //if (_formKey.currentState!.validate()) {
    // Unfocus to close keyboard before popping (optional, just looks nicer)
    FocusScope.of(context).unfocus();
    context.read<ArkCubit>().updateAmount(
      amount: _controller.text,
      currencyCode: _currencyCode,
    );
    //}
  }

  String _calculateEquivalentAmount() {
    final inputAmount = _controller.text;
    final exchangeRate = context.read<ArkCubit>().state.exchangeRate;
    final bitcoinUnit = context.read<ArkCubit>().state.preferredBitcoinUnit;
    final equivalentCurrencyCode = context
        .read<ArkCubit>()
        .state
        .equivalentCurrencyCode;
    String equivalentValue = '0';
    if (_currencyCode == BitcoinUnit.sats.code) {
      final amountSat = int.tryParse(inputAmount) ?? 0;
      equivalentValue = (amountSat / 1e8 * exchangeRate).toStringAsFixed(2);
    } else if (_currencyCode == BitcoinUnit.btc.code) {
      final amountBtc = double.tryParse(inputAmount) ?? 0;
      equivalentValue = (amountBtc * exchangeRate).toStringAsFixed(2);
    } else {
      final amountFiat = double.tryParse(inputAmount) ?? 0;
      equivalentValue = bitcoinUnit == BitcoinUnit.sats
          ? (amountFiat * 1e8 / exchangeRate).toStringAsFixed(0)
          : (amountFiat / exchangeRate).toStringAsFixed(8);
    }
    return '$equivalentValue $equivalentCurrencyCode';
  }

  String _calculateMaxAmountValue() {
    if (_maxSpendableSat != null) {
      if (_preferredBitcoinUnit == BitcoinUnit.btc) {
        return (_maxSpendableSat! / 1e8).toStringAsFixed(8);
      } else {
        return '$_maxSpendableSat';
      }
    }
    return '0';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // tap outside input to close keyboard
      behavior: .opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            context.loc.arkSendAmountTitle,
            style: context.font.headlineMedium,
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: _isLoading
                ? FadingLinearProgress(
                    height: 3,
                    trigger: _isLoading,
                    backgroundColor: context.appColors.surface,
                    foregroundColor: context.appColors.primary,
                  )
                : const SizedBox(height: 3),
          ),
        ),
        body: SafeArea(
          child: Form(
            child: ScrollableColumn(
              mainAxisAlignment: .spaceBetween,
              children: [
                PriceInput(
                  currency: _currencyCode,
                  amountEquivalent: _equivalentAmount,
                  availableCurrencies: _availableCurrencies,
                  onCurrencyChanged: _onCurrencyCodeChanged,
                  onNoteChanged: null,
                  amountController: _controller,
                  focusNode: _focusNode,
                  error: _error,
                ),
                Column(
                  mainAxisAlignment: .spaceBetween,
                  children: [
                    Divider(
                      height: 1,
                      color: context.appColors.secondaryFixedDim,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: BalanceRow(
                        balance: _preferredBitcoinUnit == BitcoinUnit.btc
                            ? (_maxSpendableSat != null
                                  ? (_maxSpendableSat! / 1e8).toStringAsFixed(8)
                                  : '0.00000000')
                            : (_maxSpendableSat?.toString() ?? '0'),
                        currencyCode: _preferredBitcoinUnit.code,
                        onMaxPressed: () async {
                          await context
                              .read<ArkCubit>()
                              .onSendCurrencyCodeChanged(
                                _preferredBitcoinUnit.code,
                              );
                          _controller.text = _calculateMaxAmountValue();
                        },
                        walletLabel: context.loc.arkInstantPayments,
                      ),
                    ),
                  ],
                ),
                BBButton.big(
                  label: context.loc.arkContinueButton,
                  onPressed: _submit,
                  disabled: _controller.text.isEmpty || _isLoading,
                  bgColor: context.appColors.secondary,
                  textColor: context.appColors.onSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
