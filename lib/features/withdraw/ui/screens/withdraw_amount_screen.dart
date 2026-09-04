import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/bb_keyboard_actions.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/withdraw/domain/withdraw_failure.dart';
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
      // The user summary load is what unlocks this screen: without it the
      // currency never arrives, the amount fields shimmer forever and Continue
      // stays disabled. So a failed load replaces the form with the reason and
      // a way out — WithdrawStarted is dispatched once by the router, so
      // without a retry here the only recovery is leaving the flow.
      body: BlocBuilder<WithdrawBloc, WithdrawState>(
        buildWhen: (previous, current) =>
            previous is WithdrawInitialState || current is WithdrawInitialState,
        builder: (context, state) {
          if (state case WithdrawInitialState(failure: final failure?)) {
            return _LoadFailed(failure: failure);
          }
          return _buildForm(context);
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return SafeArea(
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

/// The exchange account summary failed to load, so there is no currency and no
/// form to fill. Show why and let the user ask again without leaving the flow.
class _LoadFailed extends StatelessWidget {
  final WithdrawFailure failure;

  const _LoadFailed({required this.failure});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: .center,
            children: [
              BBText(
                failure.toTranslated(context),
                textAlign: TextAlign.center,
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.error,
                ),
              ),
              const Gap(16),
              BBButton.big(
                label: context.loc.retry,
                onPressed: () => context.read<WithdrawBloc>().add(
                  const WithdrawEvent.started(),
                ),
                bgColor: context.appColors.onSurface,
                textColor: context.appColors.surface,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
