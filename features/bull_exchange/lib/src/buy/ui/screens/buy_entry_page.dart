import 'dart:async';

import 'package:bull_exchange/src/buy/domain/buy_flow.dart';
import 'package:bull_exchange/src/buy/ui/buy_amount_text.dart';
import 'package:bull_exchange/src/buy/ui/buy_payout_method_label.dart';
import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/exchange_payout_field.dart';
import 'package:bull_exchange/src/funding/fund_exchange_router.dart';
import 'package:bull_exchange/src/steps_l10n.dart';
import 'package:bull_exchange/src/ui/amount_problem_l10n.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullAmountInputFormatter,
        BullButton,
        BullDropdown,
        BullInfoCard,
        BullKeyboardActions,
        BullPickerItem,
        BullScrollableColumn,
        BullShapesX,
        BullShimmerLine,
        BullSwitch,
        BullTypographyX,
        Gap;
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit, FormatAmount;

/// The buy entry: the amount in a funded balance's currency (fiat or the
/// user's bitcoin unit), the payout wallet or an external address, and the
/// payjoin switch. The amount is checked live for the KYC level and the
/// balance, as before; every button is an event of the flow.
class BuyEntryPage extends StatefulWidget {
  const BuyEntryPage({
    super.key,
    required this.entry,
    required this.unit,
    required this.payoutField,
    required this.onEvent,
  });

  final BuyEntry entry;
  final BitcoinUnit unit;
  final ExchangePayoutField payoutField;
  final void Function(BuyFlowEvent event) onEvent;

  @override
  State<BuyEntryPage> createState() => _BuyEntryPageState();
}

class _BuyEntryPageState extends State<BuyEntryPage> {
  late final TextEditingController _amount = TextEditingController(
    text: _fieldText,
  );
  final FocusNode _focus = FocusNode();
  String _address = '';

  AmountEditing? get _editing => switch (widget.entry.amount) {
    final AmountEditing editing => editing,
    AmountNoMarket() ||
    AmountKycDetour() ||
    AmountFundingDetour() ||
    AmountDone() ||
    AmountSessionRejected() => null,
  };

  String get _fieldText => switch (_editing) {
    final editing? => BuyAmountText.toField(
      editing.draft.text,
      editing.draft.unit,
      widget.unit,
    ),
    null => '',
  };

  @override
  void initState() {
    super.initState();
    _amount.addListener(_typed);
    if (widget.entry.destination case PickChosen(
      value: DestinationAddress(:final address),
    )) {
      _address = address;
    }
  }

  @override
  void didUpdateWidget(BuyEntryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final editing = _editing;
    if (editing == null) return;
    final shown = BuyAmountText.toDraft(
      _amount.text,
      editing.draft.unit,
      widget.unit,
    );
    if (shown != editing.draft.text) _amount.text = _fieldText;
  }

  void _typed() {
    final editing = _editing;
    if (editing == null) return;
    final text = BuyAmountText.toDraft(
      _amount.text,
      editing.draft.unit,
      widget.unit,
    );
    if (text == editing.draft.text) return;
    widget.onEvent(BuyAmountChanged(AmountTyped(text)));
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
    final entry = widget.entry;
    final editing = _editing;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.buyInputTitle),
        leading: BackButton(
          onPressed: () => widget.onEvent(const BuyBackPressed()),
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
              if (editing == null)
                _NoFundedBalance(onEvent: widget.onEvent)
              else ...[
                _amountCard(context, editing),
                const Gap(16),
                _paymentMethod(context, entry, editing),
                const Gap(16),
                _destination(context, entry),
                if (entry.offersPayjoin) ...[
                  const Gap(16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.loc.payjoinUseToggle,
                          style: context.bullType.body,
                        ),
                      ),
                      BullSwitch(
                        value: entry.payjoin,
                        onChanged: (enabled) =>
                            widget.onEvent(BuyPayjoinToggled(enabled)),
                      ),
                    ],
                  ),
                ],
                const Spacer(),
                ..._bottom(context, entry, editing),
              ],
              const Gap(16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _amountCard(BuildContext context, AmountEditing editing) {
    final currency = editing.draft.market.currency;
    final inFiat = editing.draft.unit == AmountUnit.fiat;
    final code = inFiat ? currency.code : widget.unit.code;
    final decimals = inFiat ? currency.decimals : widget.unit.decimals;
    final balance = editing.context.balanceOf(currency);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.loc.buyEnterAmount, style: context.bullType.body),
        const Gap(4),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.bullShapes.input),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _amount,
                        focusNode: _focus,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          BullAmountInputFormatter(code, maxDecimals: decimals),
                        ],
                        style: context.bullType.headline.copyWith(
                          color: context.appColors.primary,
                        ),
                        decoration: InputDecoration(
                          hintText: NumberFormat.decimalPatternDigits(
                            decimalDigits: decimals,
                          ).format(0),
                          hintStyle: context.bullType.headline.copyWith(
                            color: context.appColors.onSurfaceVariant,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const Gap(8),
                    Text(
                      code,
                      style: context.bullType.headline.copyWith(
                        color: context.appColors.primary,
                      ),
                    ),
                  ],
                ),
                const Gap(16),
                Row(
                  children: [
                    InkWell(
                      onTap: () => widget.onEvent(
                        const BuyAmountChanged(AmountUnitToggled()),
                      ),
                      child: Icon(
                        Icons.swap_vert,
                        color: context.appColors.outline,
                      ),
                    ),
                    const Gap(8),
                    Text(
                      inFiat ? widget.unit.code : currency.code,
                      style: context.bullType.body.copyWith(
                        color: context.appColors.outline,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        if (!inFiat) {
                          widget.onEvent(
                            const BuyAmountChanged(AmountUnitToggled()),
                          );
                        }
                        widget.onEvent(
                          BuyAmountChanged(
                            AmountTyped(
                              balance.toStringAsFixed(currency.decimals),
                            ),
                          ),
                        );
                      },
                      child: Text(
                        context.loc.buyMax,
                        style: context.bullType.body.copyWith(
                          color: context.appColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _paymentMethod(
    BuildContext context,
    BuyEntry entry,
    AmountEditing editing,
  ) {
    final markets = amountMarkets(buyAmountPolicy, editing.context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.loc.buyPaymentMethod, style: context.bullType.body),
        const Gap(4),
        BullDropdown<String>(
          value: editing.draft.market.currency.code,
          items: [
            for (final market in markets)
              BullPickerItem(
                value: market.currency.code,
                label:
                    '${market.currency.code} Balance - '
                    '${FormatAmount.fiat(editing.context.balanceOf(market.currency), market.currency.code, simpleFormat: true)}',
              ),
          ],
          onChanged: (code) {
            if (ExchangeCatalog.parse(code) case KnownCurrency(:final market)) {
              widget.onEvent(BuyAmountChanged(AmountMarketChosen(market)));
            }
          },
        ),
      ],
    );
  }

  Widget _destination(BuildContext context, BuyEntry entry) {
    final wallets = entry.open.context.wallets;
    final selected = entry.selectedWallet;
    final destination = entry.destination;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.loc.buySelectWallet, style: context.bullType.body),
        const Gap(4),
        BullDropdown<String?>(
          value: selected?.walletId,
          items: [
            for (final wallet in wallets)
              BullPickerItem<String?>(
                value: wallet.walletId,
                label: wallet.isDefault
                    ? '${wallet.displayLabel(context)} '
                          '(${buyPayoutMethodLabel(context, isLiquid: wallet.rail == BtcNetwork.liquid)})'
                    : wallet.displayLabel(context),
              ),
            BullPickerItem<String?>(
              value: null,
              label: context.loc.buyConfirmExternalWallet,
            ),
          ],
          onChanged: (walletId) => widget.onEvent(
            BuyDestinationPicked(
              walletId == null
                  ? null
                  : entry.open.context.walletOf(walletId)?.option,
            ),
          ),
        ),
        if (destination case PickChoosing(problem: PickResolveFailed())) ...[
          const Gap(8),
          Text(
            context.loc.buyPayoutAddressUnavailable,
            style: context.bullType.body.copyWith(
              color: context.appColors.error,
            ),
          ),
        ],
        if (destination is PickResolving<DestinationOption, Destination>) ...[
          const Gap(8),
          const BullShimmerLine(height: 14, width: 160),
        ],
        if (selected == null) ...[
          const Gap(16),
          widget.payoutField(
            value: _address,
            label: context.loc.buyEnterBitcoinAddress,
            hint: context.loc.buyBitcoinAddressHint,
            type: BtcNetwork.bitcoin,
            enabled: true,
            onChanged: (value) {
              setState(() => _address = value);
              widget.onEvent(BuyAddressTyped(value));
            },
            onValidated: (address) {
              if (address != null) widget.onEvent(BuyAddressTyped(address));
            },
          ),
        ],
      ],
    );
  }

  List<Widget> _bottom(
    BuildContext context,
    BuyEntry entry,
    AmountEditing editing,
  ) {
    final currency = editing.draft.market.currency.code;
    final problem = editing.problem;
    final check = checkAmount(
      buyAmountPolicy,
      editing.draft,
      editing.quote,
      editing.context,
    );
    final chosen = entry.destination is PickChosen;
    void next() => widget.onEvent(const BuyContinuePressed());
    final errorStyle = context.bullType.body.copyWith(
      color: context.appColors.error,
    );
    return [
      if (problem != null) ...[
        Center(
          child: Text(
            problem.toTranslated(context, currency),
            style: errorStyle,
            textAlign: TextAlign.center,
          ),
        ),
        const Gap(16),
      ],
      if (editing.quote case RateFailed(:final problem)) ...[
        Center(
          child: Text(
            problem.toTranslated(context),
            style: errorStyle,
            textAlign: TextAlign.center,
          ),
        ),
        const Gap(8),
        BullButton.secondary(
          label: context.loc.retry,
          onPressed: () =>
              widget.onEvent(const BuyAmountChanged(AmountRateRetryPressed())),
        ),
        const Gap(16),
      ],
      ...switch (check) {
        AmountCheckKycRequired() => [
          _card(
            context,
            context.loc.buyInputKycPending,
            context.loc.buyInputKycMessage,
          ),
          const Gap(16),
          BullButton.primary(
            label: context.loc.buyInputCompleteKyc,
            onPressed: next,
          ),
        ],
        AmountCheckShortfall() => [
          _card(
            context,
            context.loc.buyInputInsufficientBalance,
            context.loc.buyInputInsufficientBalanceMessage,
          ),
          const Gap(16),
          BullButton.primary(
            label: context.loc.buyInputFundAccount,
            onPressed: next,
          ),
        ],
        AmountCheckPassed() || AmountCheckRefused() => [
          BullButton.primary(
            label: context.loc.buyInputContinue,
            onPressed: chosen ? next : null,
          ),
        ],
      },
    ];
  }
}

Widget _card(BuildContext context, String title, String description) =>
    BullInfoCard(
      title: title,
      description: description,
      bgColor: context.appColors.tertiary.withValues(alpha: 0.1),
      tagColor: context.appColors.onTertiary,
    );

/// No balance can fund a buy: the user funds the account and comes back to
/// the flow, which reads the account again.
class _NoFundedBalance extends StatelessWidget {
  const _NoFundedBalance({required this.onEvent});

  final void Function(BuyFlowEvent event) onEvent;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _card(
          context,
          context.loc.buyInputInsufficientBalance,
          context.loc.buyInputInsufficientBalanceMessage,
        ),
        const Gap(16),
        BullButton.primary(
          label: context.loc.buyInputFundAccount,
          onPressed: () => unawaited(
            context
                .push<void>(FundExchangeRoute.fundExchange.path)
                .then((_) => onEvent(const BuyFundingReturned())),
          ),
        ),
      ],
    ),
  );
}
