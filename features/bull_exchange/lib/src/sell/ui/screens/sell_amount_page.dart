import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/sell/domain/sell_state.dart';
import 'package:bull_exchange/src/sell/domain/sell_event.dart';
import 'package:bull_exchange/src/steps_l10n.dart';
import 'package:bull_exchange/src/ui/amount_problem_l10n.dart';
import 'package:bull_exchange/src/ui/widgets/exchange_amount_currency_dropdown.dart';
import 'package:bull_exchange/src/ui/widgets/exchange_amount_input_field.dart';
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

/// The amount step of the sell flow while it is editing: any market, the
/// amount in fiat or in BTC. The step checks it on Continue.
class SellAmountPage extends StatefulWidget {
  const SellAmountPage({
    super.key,
    required this.open,
    required this.editing,
    required this.onEvent,
  });

  final SellOpen open;
  final AmountEditing editing;
  final void Function(SellFlowEvent event) onEvent;

  @override
  State<SellAmountPage> createState() => _SellAmountPageState();
}

class _SellAmountPageState extends State<SellAmountPage> {
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
  void didUpdateWidget(SellAmountPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final text = widget.editing.draft.text;
    if (text != _amount.text) _amount.text = text;
  }

  void _typed() {
    if (_amount.text == widget.editing.draft.text) return;
    widget.onEvent(SellAmountChanged(AmountTyped(_amount.text)));
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
    final markets = amountMarkets(
      sellAmountPolicy,
      widget.open.context.amountContext,
    );
    final problem = editing.problem;
    final quote = editing.quote;
    final inBitcoin = editing.draft.unit == AmountUnit.bitcoin;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.sellTitle),
        leading: BackButton(
          onPressed: () => widget.onEvent(const SellBackPressed()),
        ),
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
              ),
              const Gap(8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => widget.onEvent(
                    const SellAmountChanged(AmountUnitToggled()),
                  ),
                  child: Text(
                    inBitcoin
                        ? market.currency.code
                        : context.loc.sellBitcoinAmount,
                  ),
                ),
              ),
              const Gap(8),
              ExchangeAmountCurrencyDropdown(
                currencies: [for (final market in markets) market.currency],
                initialCurrency: market.currency,
                selectedCurrency: market.currency,
                balances: const [],
                onCurrencyChanged: (currency) => widget.onEvent(
                  SellAmountChanged(
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
                    const SellAmountChanged(AmountRateRetryPressed()),
                  ),
                ),
              ],
              const Spacer(),
              BullButton.primary(
                label: context.loc.continueButton,
                onPressed: () => widget.onEvent(
                  const SellAmountChanged(AmountContinuePressed()),
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
