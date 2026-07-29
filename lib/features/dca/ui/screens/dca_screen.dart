import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/inputs/bb_keyboard_actions.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/dca/domain/dca.dart';
import 'package:bb_mobile/features/dca/presentation/dca_bloc.dart';
import 'package:bb_mobile/features/dca/presentation/dca_failure_l10n.dart';
import 'package:bb_mobile/features/dca/ui/widgets/dca_amount_input_fields.dart';
import 'package:bb_mobile/features/dca/ui/widgets/dca_frequency_radio_list.dart';
import 'package:bb_mobile/features/fund_exchange/fund_exchange_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class DcaScreen extends StatefulWidget {
  const DcaScreen({super.key});

  @override
  State<DcaScreen> createState() => _DcaScreenState();
}

class _DcaScreenState extends State<DcaScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController = TextEditingController();
  final FocusNode _amountNode = FocusNode();
  bool _hasFunds = true;
  FiatCurrency? _fiatCurrency;
  DcaBuyFrequency? _frequency;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DcaBloc, DcaState>(
      listenWhen: (previous, current) =>
          previous is DcaInitialState && current is DcaBuyInputState,
      listener: (context, state) {
        setState(() {
          _hasFunds = state.balances.isNotEmpty;
          _fiatCurrency = state.currency;
        });
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          appBar: AppBar(title: Text(context.loc.dcaSetupTitle)),
          body: SafeArea(
            child: BBKeyboardActions(
              disableScroll: true,
              focusNodes: [_amountNode],
              child: Form(
                key: _formKey,
                child: ScrollableColumn(
                  crossAxisAlignment: .start,
                  children: [
                    const Gap(24),
                    // A failed account load previously left this screen with
                    // no feedback at all; surface the sanitized failure.
                    if (context.select(
                          (DcaBloc bloc) => switch (bloc.state) {
                            DcaInitialState(:final failure) => failure,
                            _ => null,
                          },
                        )
                        case final failure?) ...[
                      Text(
                        failure.toTranslated(context),
                        style: context.font.bodySmall?.copyWith(
                          color: context.appColors.error,
                        ),
                      ),
                      const Gap(16),
                    ],
                    if (!_hasFunds) ...[
                      const Spacer(),
                      InfoCard(
                        title: context.loc.dcaSetupInsufficientBalance,
                        description:
                            context.loc.dcaSetupInsufficientBalanceMessage,
                        bgColor: context.appColors.tertiary.withValues(
                          alpha: 0.1,
                        ),
                        tagColor: context.appColors.onTertiary,
                      ),
                      const Gap(16.0),
                      BBButton.big(
                        label: context.loc.dcaSetupFundAccount,
                        onPressed: () {
                          context.pushReplacementNamed(
                            FundExchangeRoute.fundExchange.name,
                          );
                        },
                        bgColor: context.appColors.primary,
                        textColor: context.appColors.onPrimary,
                      ),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: Text(
                          context.loc.dcaSetupScheduleMessage,
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: .center,
                        ),
                      ),
                      const Gap(24),
                      DcaAmountInputFields(
                        amountController: _amountController,
                        focusNode: _amountNode,
                        fiatCurrency: _fiatCurrency,
                        onFiatCurrencyChanged: (fiatCurrency) {
                          setState(() {
                            _fiatCurrency = fiatCurrency;
                          });
                        },
                      ),
                      const Gap(24),
                      FormField<DcaBuyFrequency>(
                        initialValue: _frequency,
                        validator: (val) => val == null
                            ? context.loc.dcaSetupFrequencyError
                            : null,
                        builder: (field) {
                          return DcaFrequencyRadioList(
                            selectedFrequency: field.value,
                            onChanged: (freq) {
                              FocusManager.instance.primaryFocus?.unfocus();
                              field.reset();
                              setState(() => _frequency = freq);
                              field.didChange(freq);
                            },
                            errorText: field.errorText,
                          );
                        },
                      ),
                      const Spacer(),
                      BBButton.big(
                        label: context.loc.dcaSetupContinue,
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            context.read<DcaBloc>().add(
                              DcaEvent.buyInputContinuePressed(
                                amountInput: _amountController.text,
                                currency: _fiatCurrency!,
                                frequency: _frequency!,
                              ),
                            );
                          }
                        },
                        bgColor: context.appColors.secondary,
                        textColor: context.appColors.onSecondary,
                      ),
                    ],
                    const Gap(16.0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
