import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/price_input/price_input.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
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
  //String? _error;

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
        _controller.text = '';
        setState(() {
          _currencyCode = state.currencyCode!;
        });
      }

      // Calculate equivalent amount when exchange rate changes
      if (_controller.text.isNotEmpty) {
        final inputAmount = double.tryParse(_controller.text);
        final equivalentValue =
            (inputAmount ?? 0) * state.inputVsEquivalentExchangeRate;
        setState(() {
          _equivalentAmount =
              '$equivalentValue ${state.equivalentCurrencyCode}';
        });
      }

      if (state.error != null) {
        setState(() {
          //_error = state.error!.message;
        });
      } else {
        setState(() {
          // _error = null;
        });
      }
    });

    _controller.addListener(() {
      // Calculate equivalent amount when input changes
      final inputAmount = double.tryParse(_controller.text);
      final exchangeRate =
          context.read<ArkCubit>().state.inputVsEquivalentExchangeRate;

      final equivalentValue = (inputAmount ?? 0) * exchangeRate;
      setState(() {
        _equivalentAmount =
            '$equivalentValue ${context.read<ArkCubit>().state.equivalentCurrencyCode}';
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
    }
  }

  void _submit() {
    //if (_formKey.currentState!.validate()) {
    // Unfocus to close keyboard before popping (optional, just looks nicer)
    FocusScope.of(context).unfocus();
    context.read<ArkCubit>().updateAmount(
      amount: _controller.text,
      currencyCode: _currencyCode,
    );
    //}
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // tap outside input to close keyboard
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Enter Amount', style: context.font.headlineMedium),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child:
                _isLoading
                    ? FadingLinearProgress(
                      height: 3,
                      trigger: _isLoading,
                      backgroundColor: context.colour.surface,
                      foregroundColor: context.colour.primary,
                    )
                    : const SizedBox(height: 3),
          ),
        ),
        body: SafeArea(
          child: Form(
            child: ScrollableColumn(
              children: [
                PriceInput(
                  currency: _currencyCode,
                  amountEquivalent: _equivalentAmount,
                  availableCurrencies: _availableCurrencies,
                  onCurrencyChanged: _onCurrencyCodeChanged,
                  onNoteChanged: null,
                  amountController: _controller,
                  focusNode: _focusNode,
                ),
                const Spacer(),
                BBButton.big(
                  label: 'Continue',
                  onPressed: _submit,
                  disabled: _controller.text.isEmpty || _isLoading,
                  bgColor: context.colour.secondary,
                  textColor: context.colour.onSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
