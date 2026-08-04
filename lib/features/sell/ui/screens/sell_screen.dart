import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/inputs/bb_keyboard_actions.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/sell/presentation/bloc/sell_bloc.dart';
import 'package:bb_mobile/features/sell/presentation/sell_failure_l10n.dart';
import 'package:bb_mobile/features/sell/ui/widgets/sell_amount_currency_dropdown.dart';
import 'package:bb_mobile/features/sell/ui/widgets/sell_amount_input_bottom_buttons.dart';
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
  final FocusNode _amountNode = FocusNode();
  bool _isFiatCurrencyInput = true;
  FiatCurrency? _fiatCurrency;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Adding the leading icon button here manually since we are in the first
        // route of a shellroute and so no back button is provided by default.
        leading: context.canPop()
            ? BackButton(
                onPressed: () {
                  context.pop();
                },
              )
            : null,
        title: Text(context.loc.sellTitle),
      ),
      body: SafeArea(
        child: BBKeyboardActions(
          disableScroll: true,
          focusNodes: [_amountNode],
          child: Form(
            key: _formKey,
            child: ScrollableColumn(
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
                const Gap(16.0),
                const _SellErrorCard(),
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

class _SellErrorCard extends StatelessWidget {
  const _SellErrorCard();

  @override
  Widget build(BuildContext context) {
    final failure = context.select(
      (SellBloc bloc) => bloc.state is SellInitialState
          ? (bloc.state as SellInitialState).failure
          : null,
    );

    if (failure == null) return const SizedBox.shrink();

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Text(
          failure.toTranslated(context),
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.error,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
