import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/inputs/bb_keyboard_actions.dart';
import 'package:bb_mobile/features/sell/ui/widgets/sell_amount_currency_dropdown.dart';
import 'package:bb_mobile/features/sell/ui/widgets/sell_amount_input_bottom_buttons.dart';
import 'package:bb_mobile/features/sell/ui/widgets/sell_amount_input_field.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

class SellScreen extends StatefulWidget {
  const SellScreen({super.key});

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController = TextEditingController();
  final FocusNode _amountNode = FocusNode();
  bool _isFiatCurrencyInput = true;
  FiatCurrency? _fiatCurrency;

  @override
  Widget build(BuildContext context) {
    return BullPage(
      topBar: BullTopBar(
        title: context.loc.sellTitle,
        onBack: context.canPop() ? context.pop : null,
      ),
      safeArea: false,
      child: SafeArea(
        child: BBKeyboardActions(
          disableScroll: true,
          focusNodes: [_amountNode],
          child: Form(
            key: _formKey,
            child: BullScrollableColumn(
              crossAxisAlignment: .start,
              children: [
                const Gap(24.0),
                SellAmountInputField(
                  amountController: _amountController,
                  focusNode: _amountNode,
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
                SellAmountInputBottomButtons(
                  formKey: _formKey,
                  amountController: _amountController,
                  isFiatCurrencyInput: _isFiatCurrencyInput,
                  fiatCurrency: _fiatCurrency,
                ),
                const Gap(16.0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountNode.dispose();
    super.dispose();
  }
}
