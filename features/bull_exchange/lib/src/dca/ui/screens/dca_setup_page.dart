import 'dart:async';

import 'package:bull_exchange/src/dca/domain/dca_state.dart';
import 'package:bull_exchange/src/dca/domain/dca_event.dart';
import 'package:bull_exchange/src/dca/ui/widgets/dca_frequency_radio_list.dart';
import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/funding/fund_exchange_router.dart';
import 'package:bull_exchange/src/steps_l10n.dart';
import 'package:bull_exchange/src/ui/amount_problem_l10n.dart';
import 'package:bull_exchange/src/ui/widgets/exchange_amount_currency_dropdown.dart';
import 'package:bull_exchange/src/ui/widgets/exchange_amount_input_field.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullInfoCard,
        BullKeyboardActions,
        BullScrollableColumn,
        BullTypographyX,
        Gap;
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The DCA amount (fiat, in a funded balance) and frequency.
class DcaSetupPage extends StatefulWidget {
  const DcaSetupPage({super.key, required this.setup, required this.onEvent});

  final DcaSetup setup;
  final void Function(DcaFlowEvent event) onEvent;

  @override
  State<DcaSetupPage> createState() => _DcaSetupPageState();
}

class _DcaSetupPageState extends State<DcaSetupPage> {
  late final TextEditingController _amount = TextEditingController(
    text: _editing?.draft.text ?? '',
  );
  final FocusNode _focus = FocusNode();

  AmountEditing? get _editing => switch (widget.setup.amount) {
    final AmountEditing editing => editing,
    AmountNoMarket() ||
    AmountKycDetour() ||
    AmountFundingDetour() ||
    AmountDone() ||
    AmountSessionRejected() => null,
  };

  @override
  void initState() {
    super.initState();
    _amount.addListener(_typed);
  }

  @override
  void didUpdateWidget(DcaSetupPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final text = _editing?.draft.text;
    if (text != null && text != _amount.text) _amount.text = text;
  }

  void _typed() {
    final editing = _editing;
    if (editing == null || editing.draft.text == _amount.text) return;
    widget.onEvent(DcaAmountChanged(AmountTyped(_amount.text)));
  }

  @override
  void dispose() {
    _amount.removeListener(_typed);
    _amount.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final setup = widget.setup;
    final editing = _editing;
    final summary = setup.open.context.summary;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.loc.dcaSetupTitle),
          leading: BackButton(
            onPressed: () => widget.onEvent(const DcaBackPressed()),
          ),
        ),
        body: SafeArea(
          child: BullKeyboardActions(
            doneText: context.loc.doneButton,
            disableScroll: true,
            child: BullScrollableColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Gap(24),
                if (editing == null) ...[
                  const Spacer(),
                  BullInfoCard(
                    title: context.loc.dcaSetupInsufficientBalance,
                    description: context.loc.dcaSetupInsufficientBalanceMessage,
                    bgColor: context.appColors.tertiary.withValues(alpha: 0.1),
                    tagColor: context.appColors.onTertiary,
                  ),
                  const Gap(16),
                  BullButton.primary(
                    label: context.loc.dcaSetupFundAccount,
                    onPressed: () => unawaited(
                      context
                          .push<void>(FundExchangeRoute.fundExchange.path)
                          .then(
                            (_) => widget.onEvent(const DcaFundingReturned()),
                          ),
                    ),
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                      context.loc.dcaSetupScheduleMessage,
                      style: context.bullType.body,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Gap(24),
                  ExchangeAmountInputField(
                    amountController: _amount,
                    focusNode: _focus,
                    fiatCurrency: editing.draft.market.currency,
                    fiatBalance: summary.balances
                        .where(
                          (b) =>
                              b.currencyCode ==
                              editing.draft.market.currency.code,
                        )
                        .firstOrNull,
                  ),
                  const Gap(16),
                  ExchangeAmountCurrencyDropdown(
                    currencies: [
                      for (final market in amountMarkets(
                        dcaAmountPolicy,
                        editing.context,
                      ))
                        market.currency,
                    ],
                    initialCurrency: editing.draft.market.currency,
                    selectedCurrency: editing.draft.market.currency,
                    balances: summary.balances,
                    onCurrencyChanged: (currency) {
                      if (ExchangeCatalog.parse(currency.code)
                          case KnownCurrency(:final market)) {
                        widget.onEvent(
                          DcaAmountChanged(AmountMarketChosen(market)),
                        );
                      }
                    },
                  ),
                  const Gap(24),
                  DcaFrequencyRadioList(
                    selectedFrequency: setup.frequency,
                    onChanged: (frequency) {
                      FocusManager.instance.primaryFocus?.unfocus();
                      if (frequency != null) {
                        widget.onEvent(DcaFrequencyPicked(frequency));
                      }
                    },
                    errorText: setup.frequencyMissing
                        ? context.loc.dcaSetupFrequencyError
                        : null,
                  ),
                  const Spacer(),
                  if (editing.problem case final problem?) ...[
                    Text(
                      problem.toTranslated(
                        context,
                        editing.draft.market.currency.code,
                      ),
                      style: context.bullType.body.copyWith(
                        color: context.appColors.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Gap(16),
                  ],
                  if (editing.quote case RateFailed(:final problem)) ...[
                    Text(
                      problem.toTranslated(context),
                      style: context.bullType.body.copyWith(
                        color: context.appColors.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Gap(8),
                    BullButton.secondary(
                      label: context.loc.retry,
                      onPressed: () => widget.onEvent(
                        const DcaAmountChanged(AmountRateRetryPressed()),
                      ),
                    ),
                    const Gap(16),
                  ],
                  BullButton.primary(
                    label: context.loc.dcaSetupContinue,
                    onPressed: () => widget.onEvent(const DcaContinuePressed()),
                  ),
                ],
                const Gap(16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
