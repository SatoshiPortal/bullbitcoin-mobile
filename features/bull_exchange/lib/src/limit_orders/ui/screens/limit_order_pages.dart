import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/exchange_payout_field.dart';
import 'package:bull_exchange/src/limit_orders/domain/entities/limit_order_amount_limits.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_order_state.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_order_event.dart';
import 'package:bull_exchange/src/limit_orders/ui/widgets/limit_order_detail_row.dart';
import 'package:bull_exchange/src/limit_orders/ui/widgets/limit_orders_loading_bar.dart';
import 'package:bull_exchange/src/steps_l10n.dart';
import 'package:bull_exchange/src/ui/amount_problem_l10n.dart';
import 'package:bull_exchange/src/ui/widgets/exchange_amount_input_field.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart' show FormatAmount;
import 'package:url_launcher/url_launcher.dart';

typedef LimitEvents = void Function(LimitFlowEvent event);

/// The frame every page of the limit-order flow shares: the title, Back as
/// an event, a loading bar while [busy], the body and the bottom actions.
class LimitPageFrame extends StatelessWidget {
  const LimitPageFrame({
    super.key,
    required this.onEvent,
    required this.body,
    this.bottom = const [],
    this.busy = false,
    this.canGoBack = true,
  });

  final LimitEvents onEvent;
  final Widget body;
  final List<Widget> bottom;
  final bool busy;
  final bool canGoBack;

  @override
  Widget build(BuildContext context) => BullScaffold(
    body: SafeArea(
      bottom: false,
      child: Column(
        children: [
          BullTopBar(
            title: context.loc.limitOrdersTitle,
            onBack: canGoBack ? () => onEvent(const LimitBackPressed()) : null,
          ),
          SizedBox(
            height: 3,
            child: busy ? const LimitOrdersLoadingBar() : null,
          ),
          Expanded(
            child: BullKeyboardActions(
              doneText: context.loc.doneButton,
              disableScroll: true,
              nextFocus: false,
              child: body,
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: bottom.isEmpty
        ? null
        : SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (index, widget) in bottom.indexed) ...[
                    if (index > 0) const Gap(12),
                    widget,
                  ],
                ],
              ),
            ),
          ),
  );
}

Widget _primary(String label, VoidCallback? onPressed) =>
    BullButton.primary(label: label, onPressed: onPressed);

class LimitIntroPage extends StatelessWidget {
  const LimitIntroPage({super.key, required this.onEvent});

  final LimitEvents onEvent;

  @override
  Widget build(BuildContext context) => LimitPageFrame(
    onEvent: onEvent,
    bottom: [
      _primary(
        context.loc.continueButton,
        () => onEvent(const LimitContinuePressed()),
      ),
    ],
    body: BullScrollableColumn(
      padding: const EdgeInsets.all(24),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Spacer(),
        Icon(Icons.multiline_chart, size: 64, color: context.bull.primary),
        const Gap(24),
        Text(
          context.loc.limitOrdersIntroTitle,
          style: context.bullType.subtitle.copyWith(
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const Gap(12),
        Text(
          context.loc.limitOrdersIntroDescription,
          textAlign: TextAlign.center,
        ),
        const Gap(24),
        _Bullet(context.loc.limitOrdersIntroBulletPrice),
        _Bullet(context.loc.limitOrdersIntroBulletBalance),
        _Bullet(context.loc.limitOrdersIntroBulletExecution),
        const Spacer(),
      ],
    ),
  );
}

/// No funded balance: fund the account or leave.
class LimitNoBalancePage extends StatelessWidget {
  const LimitNoBalancePage({
    super.key,
    required this.onEvent,
    required this.onFund,
  });

  final LimitEvents onEvent;
  final VoidCallback onFund;

  @override
  Widget build(BuildContext context) => LimitPageFrame(
    onEvent: onEvent,
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          BullInfoCard(
            title: context.loc.limitOrdersInsufficientBalance,
            description: context.loc.limitOrdersInsufficientBalanceMessage,
            bgColor: context.bull.tertiary.withValues(alpha: 0.1),
            tagColor: context.bull.onTertiary,
          ),
          const Gap(16),
          BullButton.primary(
            label: context.loc.limitOrdersFundAccount,
            onPressed: onFund,
          ),
        ],
      ),
    ),
  );
}

/// The target price against the rate of the chosen funded currency.
class LimitTargetPage extends StatefulWidget {
  const LimitTargetPage({
    super.key,
    required this.open,
    required this.target,
    required this.loading,
    required this.onEvent,
    this.switchProblem,
  });

  final LimitOpen open;

  /// The target shown; while [loading] it is the one kept during a switch.
  final PricedTarget target;
  final bool loading;
  final ReadProblem? switchProblem;
  final LimitEvents onEvent;

  @override
  State<LimitTargetPage> createState() => _LimitTargetPageState();
}

class _LimitTargetPageState extends State<LimitTargetPage> {
  final _price = TextEditingController();
  final _discount = TextEditingController();
  final _priceFocus = FocusNode();
  final _discountFocus = FocusNode();

  @override
  void dispose() {
    _price.dispose();
    _discount.dispose();
    _priceFocus.dispose();
    _discountFocus.dispose();
    super.dispose();
  }

  void _sync(PricedTarget target) {
    // Reflect the machine's price and discount in the field the user is
    // not editing.
    if (!_priceFocus.hasFocus) {
      final text = target.limitPrice.toStringAsFixed(2);
      if (_price.text != text) _price.text = text;
    }
    if (!_discountFocus.hasFocus) {
      final text = target.discount.toStringAsFixed(0);
      if (_discount.text != text) _discount.text = text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.target;
    final code = target.market.currency.code;
    final onEvent = widget.onEvent;
    final enabled = !widget.loading;
    _sync(target);
    final switchProblem = widget.switchProblem;
    return LimitPageFrame(
      onEvent: onEvent,
      busy: widget.loading,
      bottom: [
        _primary(
          context.loc.continueButton,
          enabled ? () => onEvent(const LimitContinuePressed()) : null,
        ),
      ],
      body: BullScrollableColumn(
        padding: const EdgeInsets.all(24),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.loc.limitOrdersTargetTitle,
            style: context.bullType.subtitle.copyWith(
              fontWeight: FontWeight.w400,
            ),
          ),
          const Gap(24),
          Text(
            context.loc.limitOrdersPaymentMethod,
            style: context.bullType.body,
          ),
          const Gap(4),
          BullDropdown<Market>(
            value: target.market,
            items: [
              for (final market in widget.open.context.fundedMarkets)
                BullPickerItem(
                  value: market,
                  label:
                      '${market.currency.code} — '
                      '${FormatAmount.fiat(widget.open.context.balanceOf(market), market.currency.code)}',
                ),
            ],
            onChanged: enabled
                ? (market) => onEvent(LimitCurrencyChosen(market))
                : null,
          ),
          if (switchProblem != null) ...[
            const Gap(8),
            Text(
              switchProblem.toTranslated(context),
              style: TextStyle(color: context.bull.error),
            ),
          ],
          const Gap(24),
          LimitOrderDetailRow(
            label: context.loc.limitOrdersCurrentPrice,
            value: FormatAmount.fiat(target.rate.indexPrice, code),
          ),
          const Gap(16),
          TextFormField(
            controller: _price,
            focusNode: _priceFocus,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: context.loc.limitOrdersTargetPrice,
              suffixText: code,
            ),
            onChanged: (value) {
              final price = double.tryParse(value);
              if (price != null) onEvent(LimitPriceTyped(price));
            },
          ),
          const Gap(16),
          TextFormField(
            controller: _discount,
            focusNode: _discountFocus,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: context.loc.limitOrdersDiscount,
              suffixText: '%',
            ),
            onChanged: (value) {
              final discount = double.tryParse(value);
              if (discount != null) onEvent(LimitDiscountChanged(discount));
            },
          ),
          Slider(
            min: 1,
            max: 99,
            divisions: 98,
            value: target.discount.clamp(1, 99).toDouble(),
            onChanged: enabled
                ? (value) => onEvent(LimitDiscountChanged(value))
                : null,
          ),
        ],
      ),
    );
  }
}

/// Where the bitcoin goes.
class LimitDestinationPage extends StatelessWidget {
  const LimitDestinationPage({
    super.key,
    required this.open,
    required this.pick,
    required this.payoutField,
    required this.onEvent,
    required this.onManageDefaultWallets,
  });

  final LimitOpen open;
  final LimitPickState pick;
  final ExchangePayoutField payoutField;
  final LimitEvents onEvent;
  final VoidCallback onManageDefaultWallets;

  bool _selected(DestinationOption option) => switch ((pick, option)) {
    (PickResolving(option: final resolving), _) => resolving == option,
    (
      PickChosen(value: DestinationDefaultWallet(:final rail, :final address)),
      DestinationOptionDefaultWallet(rail: final r, address: final a),
    ) =>
      rail == r && address == a,
    (
      PickChosen(value: DestinationAppWallet(:final walletId)),
      DestinationOptionAppWallet(walletId: final id),
    ) =>
      walletId == id,
    (PickChosen() || PickChoosing() || PickValidating(), _) => false,
  };

  String get _typed => switch (pick) {
    PickChosen(value: DestinationAddress(:final address)) => address,
    PickValidating(:final text) => text,
    PickChoosing(problem: PickTextInvalid(:final text)) => text,
    PickChosen() || PickChoosing() || PickResolving() => '',
  };

  void _choose(DestinationOption option) =>
      onEvent(LimitDestinationChanged(PickChose(option)));

  @override
  Widget build(BuildContext context) {
    final defaults = [
      for (final option in pick.options)
        if (option is DestinationOptionDefaultWallet) option,
    ];
    final apps = [
      for (final option in pick.options)
        if (option is DestinationOptionAppWallet) option,
    ];
    final resolving = pick is PickResolving<DestinationOption, Destination>;
    final problem = switch (pick) {
      PickChoosing(problem: PickTextInvalid()) =>
        context.loc.limitOrdersLightningAddressError,
      PickChoosing(problem: PickResolveFailed()) =>
        context.loc.oopsSomethingWentWrong,
      PickChoosing() ||
      PickResolving() ||
      PickValidating() ||
      PickChosen() => null,
    };
    Widget radio(bool selected) => Icon(
      selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      color: context.bull.primary,
    );
    return LimitPageFrame(
      onEvent: onEvent,
      busy: resolving || pick is PickValidating<DestinationOption, Destination>,
      bottom: [
        _primary(
          context.loc.continueButton,
          pick is PickChosen<DestinationOption, Destination>
              ? () => onEvent(const LimitContinuePressed())
              : null,
        ),
      ],
      body: BullScrollableColumn(
        padding: const EdgeInsets.all(24),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.loc.limitOrdersWalletTitle,
            style: context.bullType.subtitle.copyWith(
              fontWeight: FontWeight.w400,
            ),
          ),
          const Gap(12),
          Text(context.loc.limitOrdersWalletDescription),
          const Gap(24),
          for (final option in defaults) ...[
            ListTile(
              onTap: () => _choose(option),
              leading: radio(_selected(option)),
              title: Text(limitRailName(context, option.rail)),
              subtitle: Text(option.address, maxLines: 2),
            ),
            const Gap(8),
          ],
          if (apps.isNotEmpty) ...[
            const Gap(8),
            Text(
              context.loc.limitOrdersYourWalletsTitle,
              style: context.bullType.body.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const Gap(8),
            for (final option in apps) ...[
              ListTile(
                onTap: resolving ? null : () => _choose(option),
                leading: radio(_selected(option)),
                title: Text(switch (open.context
                    .appWallet(option.walletId)
                    ?.label) {
                  final label? when label.isNotEmpty => label,
                  _ => limitRailName(context, option.rail),
                }),
                subtitle: Text(limitRailName(context, option.rail)),
                trailing: resolving && _selected(option)
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
              const Gap(8),
            ],
          ],
          const Gap(8),
          payoutField(
            type: BtcNetwork.lightning,
            value: _typed,
            label: context.loc.limitOrdersLightningAddressLabel,
            hint: context.loc.limitOrdersLightningAddressHint,
            enabled: true,
            onChanged: (text) =>
                onEvent(LimitDestinationChanged(PickTyped(text))),
            onValidated: (_) {},
          ),
          if (problem != null)
            BullText(
              problem,
              style: context.bullType.caption.copyWith(
                color: context.bull.error,
              ),
            ),
          if (defaults.isEmpty && apps.isEmpty) ...[
            const Gap(16),
            BullButton.secondary(
              label: context.loc.limitOrdersManageDefaultWallets,
              onPressed: onManageDefaultWallets,
              size: BullButtonSize.small,
              compact: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// The amount in the target's currency, checked on Continue against the
/// destination rail's limits, the KYC level and the balance.
class LimitAmountPage extends StatefulWidget {
  const LimitAmountPage({
    super.key,
    required this.state,
    required this.editing,
    required this.onEvent,
  });

  final LimitAmount state;
  final AmountEditing editing;
  final LimitEvents onEvent;

  @override
  State<LimitAmountPage> createState() => _LimitAmountPageState();
}

class _LimitAmountPageState extends State<LimitAmountPage> {
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
  void didUpdateWidget(LimitAmountPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final text = widget.editing.draft.text;
    if (text != _amount.text) _amount.text = text;
  }

  void _typed() {
    if (_amount.text == widget.editing.draft.text) return;
    widget.onEvent(LimitAmountChanged(AmountTyped(_amount.text)));
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
    final state = widget.state;
    final market = state.target.market;
    final currency = market.currency;
    final fiat = parseAmountText(widget.editing.draft.text, currency.decimals);
    final problem = widget.editing.problem;
    return LimitPageFrame(
      onEvent: widget.onEvent,
      bottom: [
        _primary(
          context.loc.continueButton,
          fiat == null
              ? null
              : () => widget.onEvent(const LimitContinuePressed()),
        ),
      ],
      body: BullScrollableColumn(
        padding: const EdgeInsets.all(24),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.loc.limitOrdersAmountTitle,
            style: context.bullType.subtitle.copyWith(
              fontWeight: FontWeight.w400,
            ),
          ),
          const Gap(12),
          Text(
            context.loc.limitOrdersAvailableBalance(
              FormatAmount.fiat(
                state.open.context.balanceOf(market),
                currency.code,
              ),
            ),
          ),
          const Gap(24),
          ExchangeAmountInputField(
            amountController: _amount,
            focusNode: _focus,
            fiatCurrency: currency,
          ),
          const Gap(16),
          Text(
            context.loc.limitOrdersEstimatedBitcoin(
              FormatAmount.btc((fiat ?? 0) / state.target.limitPrice),
            ),
          ),
          if (problem != null) ...[
            const Gap(12),
            Text(
              limitAmountProblemText(
                context,
                problem,
                state.destination.rail,
                currency.code,
              ),
              style: TextStyle(color: context.bull.error),
            ),
          ],
        ],
      ),
    );
  }
}

/// The amount step's problem; the rail limits keep their own texts in
/// bitcoin.
String limitAmountProblemText(
  BuildContext context,
  AmountProblem problem,
  BtcNetwork rail,
  String currency,
) {
  String btc(int sats) =>
      FormatAmount.btc(sats / LimitOrderAmountLimits.satsPerBtc);
  return switch ((problem, rail)) {
    (AmountBelowMinimum(), BtcNetwork.liquid) =>
      context.loc.limitOrdersAmountBelowLiquidMin(
        btc(LimitOrderAmountLimits.minLiquidSats),
      ),
    (AmountBelowMinimum(), BtcNetwork.bitcoin || BtcNetwork.lightning) =>
      context.loc.limitOrdersAmountBelowOnchainMin(
        btc(LimitOrderAmountLimits.minOnChainSats),
      ),
    (AmountAboveMaximum(), _) => context.loc.limitOrdersAmountAboveLightningMax(
      btc(LimitOrderAmountLimits.maxLightningSats),
    ),
    (
      AmountNoRate() ||
          AmountInvalid() ||
          AmountOverBalance() ||
          AmountRefusedByExchange() ||
          AmountKycNeeded(),
      _,
    ) =>
      problem.toTranslated(context, currency),
  };
}

String limitRailName(BuildContext context, BtcNetwork rail) => switch (rail) {
  BtcNetwork.bitcoin => context.loc.limitOrdersWalletBitcoin,
  BtcNetwork.lightning => context.loc.limitOrdersWalletLightning,
  BtcNetwork.liquid => context.loc.limitOrdersWalletLiquid,
};

/// The text of a create that did not take effect: a refusal names its
/// reason.
String limitCreateProblemText(BuildContext context, WriteProblem problem) =>
    switch (problem) {
      WriteProblemRefused(:final reason) => switch (limitOrderRefusalOf(
        reason,
      )) {
        LimitOrderRefusal.maximumActive =>
          context.loc.limitOrdersMaximumActiveError,
        LimitOrderRefusal.invalidAddress =>
          context.loc.limitOrderInvalidAddressError,
        LimitOrderRefusal.other => context.loc.limitOrderCreationError,
      },
      WriteProblemNotSent() ||
      WriteProblemNotApplied() => problem.toTranslated(context),
    };

/// The review, and the create while it runs: the rows the old confirmation
/// showed, the terms link, and what the state allows.
class LimitReviewPage extends StatelessWidget {
  const LimitReviewPage({
    super.key,
    required this.request,
    required this.check,
    required this.onEvent,
    this.confirm,
  });

  final LimitOrderRequest request;
  final LimitReviewCheck check;

  /// The create, once Confirm was pressed.
  final LimitConfirmState? confirm;
  final LimitEvents onEvent;

  @override
  Widget build(BuildContext context) {
    final code = request.target.market.currency.code;
    final rate = switch (check) {
      ReviewLive(:final rate) || ReviewTargetAbove(:final rate) => rate,
      ReviewChecking() || ReviewCheckFailed() => request.target.rate,
    };
    final confirm = this.confirm;
    void send(LimitFlowEvent event) => onEvent(event);
    final (busy, message, actions) = switch (confirm) {
      null => switch (check) {
        ReviewChecking() => (
          true,
          null,
          <Widget>[_primary(context.loc.limitOrdersConfirm, null)],
        ),
        ReviewLive() => (
          false,
          null,
          [
            _primary(
              context.loc.limitOrdersConfirm,
              () => send(const LimitConfirmPressed()),
            ),
          ],
        ),
        ReviewTargetAbove() => (
          false,
          context.loc.limitOrderInvalidTargetError,
          <Widget>[_primary(context.loc.limitOrdersConfirm, null)],
        ),
        ReviewCheckFailed(:final problem) => (
          false,
          problem.toTranslated(context),
          [_primary(context.loc.retry, () => send(const LimitRetryPressed()))],
        ),
      },
      ConfirmConfirming() => (
        true,
        null,
        <Widget>[_primary(context.loc.limitOrdersConfirm, null)],
      ),
      ConfirmVerifying() => (
        true,
        context.loc.exchangeStepVerifying,
        <Widget>[],
      ),
      ConfirmWriteRefused(:final refusal) => (
        false,
        refusal.toTranslated(context),
        [_primary(context.loc.retry, () => send(const LimitRetryPressed()))],
      ),
      ConfirmFailed(:final problem) => (
        false,
        limitCreateProblemText(context, problem),
        [
          _primary(
            context.loc.limitOrdersConfirm,
            () => send(const LimitConfirmPressed()),
          ),
        ],
      ),
      ConfirmUnverified(:final problem) => (
        false,
        '${context.loc.exchangeStepUnverified}\n${problem.toTranslated(context)}',
        [
          _primary(
            context.loc.exchangeStepCheckAgain,
            () => send(const LimitRetryPressed()),
          ),
        ],
      ),
      ConfirmConfirmed() ||
      ConfirmSessionEnded() ||
      ConfirmLeft() => (true, null, <Widget>[]),
    };
    final canGoBack = switch (confirm) {
      null ||
      ConfirmWriteRefused() ||
      ConfirmFailed() ||
      ConfirmUnverified() => true,
      ConfirmConfirming() ||
      ConfirmVerifying() ||
      ConfirmConfirmed() ||
      ConfirmSessionEnded() ||
      ConfirmLeft() => false,
    };
    return LimitPageFrame(
      onEvent: onEvent,
      busy: busy,
      canGoBack: canGoBack,
      bottom: actions,
      body: BullScrollableColumn(
        padding: const EdgeInsets.all(24),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.loc.limitOrdersConfirmationTitle,
            style: context.bullType.subtitle.copyWith(
              fontWeight: FontWeight.w400,
            ),
          ),
          const Gap(24),
          LimitOrderDetailRow(
            label: context.loc.limitOrdersFiatAmount,
            value: FormatAmount.fiat(request.amount.fiat, code),
          ),
          const Divider(),
          LimitOrderDetailRow(
            label: context.loc.limitOrdersTargetPrice,
            value: FormatAmount.fiat(request.target.limitPrice, code),
          ),
          const Divider(),
          LimitOrderDetailRow(
            label: context.loc.limitOrdersEstimatedBuyPrice,
            value: FormatAmount.fiat(
              rate.estimatedBuyPrice(request.target.limitPrice),
              code,
            ),
          ),
          const Divider(),
          LimitOrderDetailRow(
            label: context.loc.limitOrdersPaymentMethod,
            value: context.loc.limitOrdersBalancePayment(code),
          ),
          const Divider(),
          LimitOrderDetailRow(
            label: limitRailName(context, request.destination.rail),
            value: request.destination.address,
          ),
          if (request.amount.overBalance) ...[
            const Gap(12),
            Text(
              context.loc.limitOrdersOverBalanceWarning,
              style: TextStyle(color: context.bull.onTertiary),
            ),
          ],
          const Gap(16),
          Semantics(
            link: true,
            child: GestureDetector(
              onTap: () => launchUrl(
                Uri.parse(ExchangeDefaults.exchangeTermsAndConditionsLink),
                mode: LaunchMode.inAppBrowserView,
              ),
              child: Text(
                context.loc.limitOrdersTermsNotice,
                style: context.bullType.label
                    .copyWith(fontWeight: FontWeight.w400)
                    .copyWith(
                      color: context.bull.primary,
                      decoration: TextDecoration.underline,
                    ),
              ),
            ),
          ),
          if (message != null) ...[
            const Gap(12),
            Text(message, style: TextStyle(color: context.bull.error)),
          ],
        ],
      ),
    );
  }
}

class LimitDonePage extends StatelessWidget {
  const LimitDonePage({super.key, required this.order, required this.onEvent});

  final LimitOrder order;
  final LimitEvents onEvent;

  @override
  Widget build(BuildContext context) => LimitPageFrame(
    onEvent: onEvent,
    canGoBack: false,
    bottom: [
      BullButton.secondary(
        label: context.loc.limitOrdersViewOrder,
        onPressed: () => onEvent(const LimitViewOrderPressed()),
      ),
      _primary(
        context.loc.limitOrdersBackToExchange,
        () => onEvent(const LimitDonePressed()),
      ),
    ],
    body: BullScrollableColumn(
      padding: const EdgeInsets.all(24),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Spacer(),
        Icon(Icons.check_circle, size: 72, color: context.bull.primary),
        const Gap(24),
        Text(
          context.loc.limitOrdersCreatedTitle,
          style: context.bullType.subtitle.copyWith(
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const Gap(12),
        Text(
          context.loc.limitOrdersCreatedMessage(
            FormatAmount.fiat(order.fiatAmount, order.currencyCode),
            FormatAmount.fiat(order.limitPrice, order.currencyCode),
          ),
          textAlign: TextAlign.center,
        ),
        const Spacer(),
      ],
    ),
  );
}

final class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('•'),
        const Gap(8),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
