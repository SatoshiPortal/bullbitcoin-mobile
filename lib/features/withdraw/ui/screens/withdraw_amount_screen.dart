import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/bb_keyboard_actions.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/withdraw/presentation/withdraw_bloc.dart';
import 'package:bb_mobile/features/withdraw/presentation/withdraw_failure_l10n.dart';
import 'package:bb_mobile/features/withdraw/ui/widgets/withdraw_amount_input_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:go_router/go_router.dart';

class WithdrawAmountScreen extends StatefulWidget {
  const WithdrawAmountScreen({super.key});

  @override
  State<WithdrawAmountScreen> createState() => _WithdrawAmountScreenState();
}

class _WithdrawAmountScreenState extends State<WithdrawAmountScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController = TextEditingController();
  final FocusNode _amountNode = FocusNode();
  FiatCurrency? _fiatCurrency;
  late final StreamSubscription<WithdrawState> stateSubscription;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<WithdrawBloc>();
    stateSubscription = bloc.stream.listen((state) {
      if (state is WithdrawAmountInputState && _fiatCurrency == null) {
        setState(() {
          _fiatCurrency = state.currency;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Adding the leading icon button here manually since we are in the first
        // route of a shellroute and so no back button is provided by default.
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  context.pop();
                },
              )
            : null,
        title: Text(context.loc.withdrawAmountTitle),
      ),
      // The user summary load is what unlocks this screen, so its failure has
      // to be said out loud — otherwise the currency never arrives and the
      // continue button stays disabled with no explanation.
      body: BlocListener<WithdrawBloc, WithdrawState>(
        listenWhen: (previous, current) =>
            current is WithdrawInitialState &&
            current.failure != null &&
            (previous is! WithdrawInitialState ||
                previous.failure != current.failure),
        listener: (context, state) {
          if (state case WithdrawInitialState(failure: final failure?)) {
            SnackBarUtils.showSnackBar(context, failure.toTranslated(context));
          }
        },
        child: SafeArea(
          child: BBKeyboardActions(
            disableScroll: true,
            focusNodes: [_amountNode],
            child: Form(
              key: _formKey,
              child: ScrollableColumn(
                crossAxisAlignment: .start,
                children: [
                  const Gap(40.0),
                  WithdrawAmountInputFields(
                    amountController: _amountController,
                    focusNode: _amountNode,
                    fiatCurrency: _fiatCurrency,
                    onFiatCurrencyChanged: (FiatCurrency fiatCurrency) {
                      setState(() {
                        _fiatCurrency = fiatCurrency;
                      });
                    },
                  ),
                  const Spacer(),
                  BBButton.big(
                    label: context.loc.withdrawAmountContinue,
                    disabled: _fiatCurrency == null,
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        context.read<WithdrawBloc>().add(
                          WithdrawEvent.amountInputContinuePressed(
                            amountInput: _amountController.text,
                            fiatCurrency: _fiatCurrency!,
                          ),
                        );
                      }
                    },
                    bgColor: context.appColors.onSurface,
                    textColor: context.appColors.surface,
                  ),
                  const Gap(16.0),
                ],
              ),
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
    stateSubscription.cancel();
    super.dispose();
  }
}
