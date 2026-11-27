import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/steps_l10n.dart';
import 'package:bull_exchange/src/ui/amount_problem_l10n.dart';
import 'package:bull_exchange/src/ui/widgets/exchange_amount_currency_dropdown.dart';
import 'package:bull_exchange/src/ui/widgets/exchange_amount_input_field.dart';
import 'package:bull_exchange/src/withdraw/domain/withdraw_state.dart';
import 'package:bull_exchange/src/withdraw/domain/withdraw_event.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullKeyboardActions,
        BullScrollableColumn,
        BullTypographyX,
        Gap;
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:material_ui/material_ui.dart';

/// The amount step of the withdraw flow while it is editing: the currency of
/// a funded balance and the fiat amount. The step checks it on Continue.
class WithdrawAmountPage extends StatefulWidget {
  const WithdrawAmountPage({
    super.key,
    required this.open,
    required this.editing,
    required this.onEvent,
  });

  final WithdrawOpen open;
  final AmountEditing editing;
  final void Function(WithdrawFlowEvent event) onEvent;

  @override
  State<WithdrawAmountPage> createState() => _WithdrawAmountPageState();
}

class _WithdrawAmountPageState extends State<WithdrawAmountPage> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.editing.draft.text,
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _amount.addListener(_typed);
  }

  @override
  void didUpdateWidget(WithdrawAmountPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final text = widget.editing.draft.text;
    if (text != _amount.text) _amount.text = text;
  }

  void _typed() {
    if (_amount.text == widget.editing.draft.text) return;
    widget.onEvent(WithdrawAmountChanged(AmountTyped(_amount.text)));
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
    final editing = widget.editing;
    final market = editing.draft.market;
    final balances = widget.open.context.summary.balances;
    final markets = amountMarkets(
      withdrawAmountPolicy,
      widget.open.context.amountContext,
    );
    final problem = editing.problem;
    final quote = editing.quote;
    return Scaffold(
      appBar: AppBar(
        // The flow's first page: its navigator can't pop it, so Back is
        // the flow's event, never implied.
        automaticallyImplyLeading: false,
        leading: BackButton(
          onPressed: () => widget.onEvent(const WithdrawBackPressed()),
        ),
        title: Text(context.loc.withdrawAmountTitle),
      ),
      body: SafeArea(
        child: BullKeyboardActions(
          doneText: context.loc.doneButton,
          disableScroll: true,
          child: BullScrollableColumn(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Gap(40),
              ExchangeAmountInputField(
                amountController: _amount,
                focusNode: _focus,
                fiatCurrency: market.currency,
                fiatBalance: balances
                    .where((b) => b.currencyCode == market.currency.code)
                    .firstOrNull,
              ),
              const Gap(16),
              ExchangeAmountCurrencyDropdown(
                currencies: [for (final market in markets) market.currency],
                initialCurrency: market.currency,
                selectedCurrency: market.currency,
                balances: balances,
                onCurrencyChanged: (currency) => widget.onEvent(
                  WithdrawAmountChanged(
                    AmountMarketChosen(ExchangeCatalog.market(currency)),
                  ),
                ),
              ),
              if (problem != null) ...[
                const Gap(16),
                Text(
                  problem.toTranslated(context, market.currency.code),
                  style: context.bullType.body.copyWith(
                    color: context.appColors.error,
                  ),
                ),
              ],
              if (quote case RateFailed(:final problem)) ...[
                const Gap(16),
                Text(
                  problem.toTranslated(context),
                  style: context.bullType.body.copyWith(
                    color: context.appColors.error,
                  ),
                ),
                const Gap(8),
                BullButton.secondary(
                  label: context.loc.retry,
                  onPressed: () => widget.onEvent(
                    const WithdrawAmountChanged(AmountRateRetryPressed()),
                  ),
                ),
              ],
              const Spacer(),
              BullButton.primary(
                label: context.loc.withdrawAmountContinue,
                onPressed: () => widget.onEvent(
                  const WithdrawAmountChanged(AmountContinuePressed()),
                ),
              ),
              const Gap(16),
            ],
          ),
        ),
      ),
    );
  }
}
