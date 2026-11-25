import 'package:meta/meta.dart';

import '../domain/catalog/exchange_catalog.dart';
import '../domain/catalog/kyc_policy.dart';
import '../domain/catalog/market.dart';
import '../domain/entities/order.dart';
import '../domain/exchange_call_result.dart';
import '../domain/exchange_failure.dart' show ExchangeOrderAmountBound;
import 'step_next.dart';

enum AmountUnit { fiat, bitcoin }

/// Where the flow's currency comes from.
@immutable
sealed class CurrencySource {
  const CurrencySource();
}

/// The user picks among [markets].
final class CurrencyPicker extends CurrencySource {
  final List<Market> markets;

  const CurrencyPicker(this.markets);
}

/// The user picks among the markets with a positive balance.
final class CurrencyFromFundedBalances extends CurrencySource {
  const CurrencyFromFundedBalances();
}

/// The currency is fixed by an earlier step (e.g. the recipient).
final class CurrencyFixed extends CurrencySource {
  final Market market;

  const CurrencyFixed(this.market);
}

/// What Continue does with an amount over the balance.
enum BalanceShortfall {
  /// Continue is refused with the balance shown.
  block,

  /// The flow offers funding the account and comes back to the same draft.
  offerFunding,

  /// The amount passes, marked as over the balance (limit orders: nothing is
  /// reserved, the server buys with what is there at trigger time).
  warn,
}

/// Bounds in the market's currency; null means none.
@immutable
final class AmountLimits {
  final double? minFiat;
  final double? maxFiat;

  const AmountLimits({this.minFiat, this.maxFiat});

  static const none = AmountLimits();

  /// Both bounds at once: the higher minimum and the lower maximum.
  AmountLimits and(AmountLimits other) => AmountLimits(
    minFiat: _pick(minFiat, other.minFiat, (a, b) => a > b ? a : b),
    maxFiat: _pick(maxFiat, other.maxFiat, (a, b) => a < b ? a : b),
  );

  static double? _pick(
    double? a,
    double? b,
    double Function(double, double) choose,
  ) => switch ((a, b)) {
    (final a?, final b?) => choose(a, b),
    (final a?, null) => a,
    (null, final b?) => b,
    (null, null) => null,
  };

  /// These limits with the bound the exchange refused an order for.
  AmountLimits withExchangeLimit(ExchangeOrderLimit limit) =>
      and(switch (limit.bound) {
        ExchangeOrderAmountBound.minimum => AmountLimits(minFiat: limit.amount),
        ExchangeOrderAmountBound.maximum => AmountLimits(maxFiat: limit.amount),
      });

  @override
  bool operator ==(Object other) =>
      other is AmountLimits &&
      other.minFiat == minFiat &&
      other.maxFiat == maxFiat;

  @override
  int get hashCode => Object.hash(minFiat, maxFiat);
}

/// A flow's amount rules.
@immutable
final class AmountPolicy {
  final CurrencySource currencySource;
  final bool allowBitcoinUnit;
  final bool checkBalance;
  final BalanceShortfall onShortfall;
  final bool checkKyc;
  final bool withDescription;
  final AmountLimits? limits;

  const AmountPolicy({
    required this.currencySource,
    required this.allowBitcoinUnit,
    required this.checkBalance,
    required this.onShortfall,
    required this.checkKyc,
    required this.withDescription,
    this.limits,
  });
}

/// What the checks read from the flow's loaded context.
@immutable
final class AmountContext {
  final Set<KycGroup> kycGroups;

  /// Available balance per currency; a currency missing here has none.
  final Map<FiatCurrency, double> balances;

  /// The order limits known per currency: the exchange's answers this flow
  /// has seen. A currency missing here has none known yet.
  final Map<FiatCurrency, AmountLimits> limits;

  const AmountContext({
    required this.kycGroups,
    required this.balances,
    this.limits = const {},
  });

  double balanceOf(FiatCurrency currency) => balances[currency] ?? 0;

  AmountLimits limitsOf(FiatCurrency currency) =>
      limits[currency] ?? AmountLimits.none;

  /// This context, knowing [limit]. A limit in a currency the exchange
  /// doesn't trade is not kept.
  AmountContext withExchangeLimit(ExchangeOrderLimit limit) {
    final currency = FiatCurrency.values
        .where((c) => c.code == limit.currency)
        .firstOrNull;
    if (currency == null) return this;
    return withLimits({
      ...limits,
      currency: limitsOf(currency).withExchangeLimit(limit),
    });
  }

  AmountContext withLimits(Map<FiatCurrency, AmountLimits> limits) =>
      AmountContext(kycGroups: kycGroups, balances: balances, limits: limits);

  @override
  bool operator ==(Object other) =>
      other is AmountContext &&
      _sameSet(other.kycGroups, kycGroups) &&
      _sameMap(other.balances, balances) &&
      _sameMap(other.limits, limits);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(kycGroups),
    Object.hashAllUnordered(balances.entries.map((e) => (e.key, e.value))),
    Object.hashAllUnordered(limits.entries.map((e) => (e.key, e.value))),
  );
}

bool _sameSet<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);

bool _sameMap<K, V>(Map<K, V> a, Map<K, V> b) =>
    a.length == b.length &&
    a.entries.every((e) => b.containsKey(e.key) && b[e.key] == e.value);

/// A rate, tagged with the market it was read for.
@immutable
final class MarketRate {
  final Market market;
  final double fiatPerBitcoin;

  const MarketRate(this.market, this.fiatPerBitcoin);

  @override
  bool operator ==(Object other) =>
      other is MarketRate &&
      other.market == market &&
      other.fiatPerBitcoin == fiatPerBitcoin;

  @override
  int get hashCode => Object.hash(market, fiatPerBitcoin);

  @override
  String toString() => 'MarketRate($market, $fiatPerBitcoin)';
}

/// What the user typed, in which market and unit.
@immutable
final class AmountDraft {
  final Market market;
  final String text;
  final AmountUnit unit;
  final String description;

  const AmountDraft({
    required this.market,
    this.text = '',
    this.unit = AmountUnit.fiat,
    this.description = '',
  });

  AmountDraft copyWith({
    Market? market,
    String? text,
    AmountUnit? unit,
    String? description,
  }) => AmountDraft(
    market: market ?? this.market,
    text: text ?? this.text,
    unit: unit ?? this.unit,
    description: description ?? this.description,
  );

  @override
  bool operator ==(Object other) =>
      other is AmountDraft &&
      other.market == market &&
      other.text == text &&
      other.unit == unit &&
      other.description == description;

  @override
  int get hashCode => Object.hash(market, text, unit, description);

  @override
  String toString() => 'AmountDraft($market, "$text" ${unit.name})';
}

/// The rate of the draft's market.
@immutable
sealed class RateQuote {
  const RateQuote();

  Market get market;
}

final class RateLoading extends RateQuote {
  @override
  final Market market;

  const RateLoading(this.market);

  @override
  bool operator ==(Object other) =>
      other is RateLoading && other.market == market;

  @override
  int get hashCode => Object.hash(RateLoading, market);

  @override
  String toString() => 'RateLoading($market)';
}

final class RateReady extends RateQuote {
  final MarketRate rate;

  const RateReady(this.rate);

  @override
  Market get market => rate.market;

  @override
  bool operator ==(Object other) => other is RateReady && other.rate == rate;

  @override
  int get hashCode => Object.hash(RateReady, rate);

  @override
  String toString() => 'RateReady($rate)';
}

final class RateFailed extends RateQuote {
  @override
  final Market market;
  final ReadProblem problem;

  const RateFailed(this.market, this.problem);

  @override
  bool operator ==(Object other) =>
      other is RateFailed && other.market == market && other.problem == problem;

  @override
  int get hashCode => Object.hash(RateFailed, market, problem);

  @override
  String toString() => 'RateFailed($market, $problem)';
}

/// The step's output: a parsed, checked amount and the rate it was checked
/// against.
@immutable
final class EnteredAmount {
  final Market market;
  final double fiat;
  final int sats;
  final AmountUnit enteredIn;
  final String text;
  final MarketRate rate;
  final String description;

  /// Over the balance, passed under [BalanceShortfall.warn].
  final bool overBalance;

  const EnteredAmount({
    required this.market,
    required this.fiat,
    required this.sats,
    required this.enteredIn,
    required this.text,
    required this.rate,
    required this.description,
    required this.overBalance,
  });

  AmountDraft get draft => AmountDraft(
    market: market,
    text: text,
    unit: enteredIn,
    description: description,
  );

  @override
  bool operator ==(Object other) =>
      other is EnteredAmount &&
      other.market == market &&
      other.fiat == fiat &&
      other.sats == sats &&
      other.enteredIn == enteredIn &&
      other.text == text &&
      other.rate == rate &&
      other.description == description &&
      other.overBalance == overBalance;

  @override
  int get hashCode => Object.hash(
    market,
    fiat,
    sats,
    enteredIn,
    text,
    rate,
    description,
    overBalance,
  );

  @override
  String toString() =>
      'EnteredAmount($market, fiat $fiat, sats $sats, over $overBalance)';
}

/// Why Continue did not pass; shown on the step.
@immutable
sealed class AmountProblem {
  const AmountProblem();
}

/// The rate of the market is not there yet, or failed.
final class AmountNoRate extends AmountProblem {
  const AmountNoRate();
}

/// Not a positive number with at most the unit's decimals.
final class AmountInvalid extends AmountProblem {
  const AmountInvalid();
}

final class AmountBelowMinimum extends AmountProblem {
  final double minFiat;

  const AmountBelowMinimum(this.minFiat);

  @override
  bool operator ==(Object other) =>
      other is AmountBelowMinimum && other.minFiat == minFiat;

  @override
  int get hashCode => Object.hash(AmountBelowMinimum, minFiat);
}

final class AmountAboveMaximum extends AmountProblem {
  final double maxFiat;

  const AmountAboveMaximum(this.maxFiat);

  @override
  bool operator ==(Object other) =>
      other is AmountAboveMaximum && other.maxFiat == maxFiat;

  @override
  int get hashCode => Object.hash(AmountAboveMaximum, maxFiat);
}

final class AmountOverBalance extends AmountProblem {
  final double available;

  const AmountOverBalance(this.available);

  @override
  bool operator ==(Object other) =>
      other is AmountOverBalance && other.available == available;

  @override
  int get hashCode => Object.hash(AmountOverBalance, available);
}

/// The exchange refused the amount for [limit], in a currency other than the
/// draft's, so the step can't check it itself.
final class AmountRefusedByExchange extends AmountProblem {
  final ExchangeOrderLimit limit;

  const AmountRefusedByExchange(this.limit);

  @override
  bool operator ==(Object other) =>
      other is AmountRefusedByExchange && other.limit == limit;

  @override
  int get hashCode => Object.hash(AmountRefusedByExchange, limit);
}

/// Back from the KYC detour, the account's level still doesn't allow the
/// amount.
final class AmountKycNeeded extends AmountProblem {
  const AmountKycNeeded();
}

/// What [checkAmount] says about a draft.
@immutable
sealed class AmountCheck {
  const AmountCheck();
}

final class AmountCheckPassed extends AmountCheck {
  final EnteredAmount amount;

  const AmountCheckPassed(this.amount);

  @override
  bool operator ==(Object other) =>
      other is AmountCheckPassed && other.amount == amount;

  @override
  int get hashCode => Object.hash(AmountCheckPassed, amount);
}

final class AmountCheckRefused extends AmountCheck {
  final AmountProblem problem;

  const AmountCheckRefused(this.problem);

  @override
  bool operator ==(Object other) =>
      other is AmountCheckRefused && other.problem == problem;

  @override
  int get hashCode => Object.hash(AmountCheckRefused, problem);
}

/// The market's KYC policy does not let the account trade this amount.
final class AmountCheckKycRequired extends AmountCheck {
  const AmountCheckKycRequired();
}

/// Over the balance, and the policy offers funding.
final class AmountCheckShortfall extends AmountCheck {
  final double available;

  const AmountCheckShortfall(this.available);

  @override
  bool operator ==(Object other) =>
      other is AmountCheckShortfall && other.available == available;

  @override
  int get hashCode => Object.hash(AmountCheckShortfall, available);
}

const _satsPerBitcoin = 100000000;

/// Reads [text] as a positive number with at most [decimals] decimals, '.'
/// as the separator (the view normalises the locale's separator).
double? parseAmountText(String text, int decimals) {
  final match = RegExp(r'^(\d+)(?:\.(\d+))?$').firstMatch(text.trim());
  if (match == null) return null;
  final fraction = match.group(2);
  if (fraction != null && fraction.length > decimals) return null;
  final value = double.tryParse(text.trim());
  if (value == null || !value.isFinite || value <= 0) return null;
  return value;
}

double _roundTo(double value, int decimals) =>
    double.parse(value.toStringAsFixed(decimals));

typedef _Parsed = ({double fiat, int sats});

_Parsed? _fromFiat(String text, FiatCurrency currency, MarketRate rate) {
  final value = parseAmountText(text, currency.decimals);
  if (value == null) return null;
  final sats = (value / rate.fiatPerBitcoin * _satsPerBitcoin).round();
  return sats <= 0 ? null : (fiat: value, sats: sats);
}

_Parsed? _fromBitcoin(String text, FiatCurrency currency, MarketRate rate) {
  final value = parseAmountText(text, 8);
  if (value == null) return null;
  final fiat = _roundTo(value * rate.fiatPerBitcoin, currency.decimals);
  return fiat <= 0
      ? null
      : (fiat: fiat, sats: (value * _satsPerBitcoin).round());
}

/// The pure check behind Continue: the rate, the number, the limits, the
/// market's KYC policy, then the balance. BTC entry is checked on its fiat
/// value like fiat entry.
AmountCheck checkAmount(
  AmountPolicy policy,
  AmountDraft draft,
  RateQuote quote,
  AmountContext context,
) {
  final rate = switch (quote) {
    RateReady(rate: final ready) when ready.market == draft.market => ready,
    RateReady() || RateLoading() || RateFailed() => null,
  };
  if (rate == null) return const AmountCheckRefused(AmountNoRate());
  final currency = draft.market.currency;
  final parsed = switch (draft.unit) {
    AmountUnit.fiat => _fromFiat(draft.text, currency, rate),
    AmountUnit.bitcoin => _fromBitcoin(draft.text, currency, rate),
  };
  if (parsed == null) return const AmountCheckRefused(AmountInvalid());
  final (:fiat, :sats) = parsed;
  final limits = (policy.limits ?? AmountLimits.none).and(
    context.limitsOf(currency),
  );
  final min = limits.minFiat;
  final max = limits.maxFiat;
  if (min != null && fiat < min) {
    return AmountCheckRefused(AmountBelowMinimum(min));
  }
  if (max != null && fiat > max) {
    return AmountCheckRefused(AmountAboveMaximum(max));
  }
  if (policy.checkKyc &&
      draft.market.kyc.needsUpgrade(context.kycGroups, fiat)) {
    return const AmountCheckKycRequired();
  }
  final available = context.balanceOf(currency);
  final over = policy.checkBalance && fiat > available;
  EnteredAmount entered(bool overBalance) => EnteredAmount(
    market: draft.market,
    fiat: fiat,
    sats: sats,
    enteredIn: draft.unit,
    text: draft.text,
    rate: rate,
    description: policy.withDescription ? draft.description : '',
    overBalance: overBalance,
  );
  if (!over) return AmountCheckPassed(entered(false));
  return switch (policy.onShortfall) {
    BalanceShortfall.block => AmountCheckRefused(AmountOverBalance(available)),
    BalanceShortfall.offerFunding => AmountCheckShortfall(available),
    BalanceShortfall.warn => AmountCheckPassed(entered(true)),
  };
}

/// The markets the user may pick under [policy].
List<Market> amountMarkets(AmountPolicy policy, AmountContext context) =>
    switch (policy.currencySource) {
      CurrencyPicker(:final markets) => markets,
      CurrencyFromFundedBalances() => [
        for (final market in ExchangeCatalog.markets)
          if (context.balanceOf(market.currency) > 0) market,
      ],
      CurrencyFixed(:final market) => [market],
    };

/// Amount entry (composition §4.3): the user types an amount in a market,
/// checked against the market's rate, KYC policy, balance and limits. Its
/// output is [EnteredAmount]; nothing downstream parses text.
@immutable
sealed class AmountEntryState {
  const AmountEntryState();
}

/// No market can be offered (e.g. nothing funded). Funding the account and
/// coming back answers [AmountDetourReturned].
final class AmountNoMarket extends AmountEntryState {
  final AmountContext context;

  const AmountNoMarket(this.context);

  @override
  bool operator ==(Object other) =>
      other is AmountNoMarket && other.context == context;

  @override
  int get hashCode => Object.hash(AmountNoMarket, context);
}

final class AmountEditing extends AmountEntryState {
  final AmountDraft draft;
  final RateQuote quote;
  final AmountContext context;

  /// Why the last Continue did not pass; cleared by the next edit.
  final AmountProblem? problem;

  const AmountEditing({
    required this.draft,
    required this.quote,
    required this.context,
    this.problem,
  });

  @override
  bool operator ==(Object other) =>
      other is AmountEditing &&
      other.draft == draft &&
      other.quote == quote &&
      other.context == context &&
      other.problem == problem;

  @override
  int get hashCode => Object.hash(draft, quote, context, problem);

  @override
  String toString() => 'AmountEditing($draft, $quote, $problem)';
}

/// The KYC web view is open over the flow; the draft waits.
final class AmountKycDetour extends AmountEntryState {
  final AmountDraft draft;
  final RateQuote quote;

  const AmountKycDetour(this.draft, this.quote);

  @override
  bool operator ==(Object other) =>
      other is AmountKycDetour && other.draft == draft && other.quote == quote;

  @override
  int get hashCode => Object.hash(AmountKycDetour, draft, quote);

  @override
  String toString() => 'AmountKycDetour($draft, $quote)';
}

/// The funding flow is open over the flow; the draft waits.
final class AmountFundingDetour extends AmountEntryState {
  final AmountDraft draft;
  final RateQuote quote;

  const AmountFundingDetour(this.draft, this.quote);

  @override
  bool operator ==(Object other) =>
      other is AmountFundingDetour &&
      other.draft == draft &&
      other.quote == quote;

  @override
  int get hashCode => Object.hash(AmountFundingDetour, draft, quote);

  @override
  String toString() => 'AmountFundingDetour($draft, $quote)';
}

final class AmountDone extends AmountEntryState {
  final EnteredAmount amount;
  final AmountContext context;

  const AmountDone(this.amount, this.context);

  @override
  bool operator ==(Object other) =>
      other is AmountDone && other.amount == amount && other.context == context;

  @override
  int get hashCode => Object.hash(AmountDone, amount, context);

  @override
  String toString() => 'AmountDone($amount)';
}

/// A rate read got HTTP 401: the flow ends its session. Terminal.
final class AmountSessionRejected extends AmountEntryState {
  const AmountSessionRejected();
}

@immutable
sealed class AmountEntryEvent {
  const AmountEntryEvent();
}

final class AmountTyped extends AmountEntryEvent {
  final String text;

  const AmountTyped(this.text);
}

final class AmountUnitToggled extends AmountEntryEvent {
  const AmountUnitToggled();
}

final class AmountDescriptionTyped extends AmountEntryEvent {
  final String text;

  const AmountDescriptionTyped(this.text);
}

final class AmountMarketChosen extends AmountEntryEvent {
  final Market market;

  const AmountMarketChosen(this.market);
}

/// The rate read for [market] answered [read] (fiat per bitcoin).
final class AmountRateArrived extends AmountEntryEvent {
  final Market market;
  final ExchangeRead<double> read;

  const AmountRateArrived(this.market, this.read);
}

final class AmountRateRetryPressed extends AmountEntryEvent {
  const AmountRateRetryPressed();
}

final class AmountContinuePressed extends AmountEntryEvent {
  const AmountContinuePressed();
}

/// Back from the KYC or funding detour, with the context read again.
final class AmountDetourReturned extends AmountEntryEvent {
  final AmountContext context;

  const AmountDetourReturned(this.context);
}

/// Back from the next step to this one.
final class AmountEditRequested extends AmountEntryEvent {
  const AmountEditRequested();
}

/// The exchange refused an order for the entered amount: it broke [limit].
/// The step goes back to editing the same draft, knowing the limit.
final class AmountLimitRefused extends AmountEntryEvent {
  final ExchangeOrderLimit limit;

  const AmountLimitRefused(this.limit);
}

@immutable
sealed class AmountEntryEffect {
  const AmountEntryEffect();
}

/// Read the rate of [market]; answer [AmountRateArrived] for it.
final class AmountFetchRate extends AmountEntryEffect {
  final Market market;

  const AmountFetchRate(this.market);

  @override
  bool operator ==(Object other) =>
      other is AmountFetchRate && other.market == market;

  @override
  int get hashCode => Object.hash(AmountFetchRate, market);

  @override
  String toString() => 'AmountFetchRate($market)';
}

/// Push the KYC web view over the flow (never replace the flow); answer
/// [AmountDetourReturned] with the context read again.
final class AmountOpenKyc extends AmountEntryEffect {
  final Market market;

  const AmountOpenKyc(this.market);

  @override
  bool operator ==(Object other) =>
      other is AmountOpenKyc && other.market == market;

  @override
  int get hashCode => Object.hash(AmountOpenKyc, market);
}

/// Push the funding flow over this one; answer [AmountDetourReturned].
final class AmountOpenFunding extends AmountEntryEffect {
  final Market market;

  const AmountOpenFunding(this.market);

  @override
  bool operator ==(Object other) =>
      other is AmountOpenFunding && other.market == market;

  @override
  int get hashCode => Object.hash(AmountOpenFunding, market);
}

typedef AmountEntryNext = StepNext<AmountEntryState, AmountEntryEffect>;

/// The first state: [preferred] if the policy offers it, else the first
/// market offered, else [AmountNoMarket].
AmountEntryNext amountEntryStart(
  AmountPolicy policy,
  AmountContext context, {
  Market? preferred,
}) {
  final markets = amountMarkets(policy, context);
  if (markets.isEmpty) return StepNext(AmountNoMarket(context));
  final market = preferred != null && markets.contains(preferred)
      ? preferred
      : markets.first;
  return StepNext(
    AmountEditing(
      draft: AmountDraft(market: market),
      quote: RateLoading(market),
      context: context,
    ),
    [AmountFetchRate(market)],
  );
}

AmountProblem? _problemOnReturn(AmountCheck check) => switch (check) {
  AmountCheckPassed() => null,
  AmountCheckRefused(:final problem) => problem,
  AmountCheckKycRequired() => const AmountKycNeeded(),
  AmountCheckShortfall(:final available) => AmountOverBalance(available),
};

/// The exchange refused [amount] for [limit]: editing the same draft again,
/// with the limit known, so Continue now refuses it here and says why.
AmountEntryNext _onLimitRefused(
  AmountPolicy policy,
  EnteredAmount amount,
  AmountContext context,
  ExchangeOrderLimit limit,
) {
  final learned = context.withExchangeLimit(limit);
  final quote = RateReady(amount.rate);
  final problem = switch (checkAmount(policy, amount.draft, quote, learned)) {
    AmountCheckRefused(
      problem: final problem && (AmountBelowMinimum() || AmountAboveMaximum()),
    ) =>
      problem,
    AmountCheckRefused() ||
    AmountCheckPassed() ||
    AmountCheckKycRequired() ||
    AmountCheckShortfall() => AmountRefusedByExchange(limit),
  };
  return StepNext(
    AmountEditing(
      draft: amount.draft,
      quote: quote,
      context: learned,
      problem: problem,
    ),
  );
}

/// A rate answer: it lands only on the rate being loaded for its market.
AmountEntryNext _onRate(
  AmountEntryState state,
  RateQuote quote,
  AmountRateArrived arrived,
  AmountEntryState Function(RateQuote quote) withQuote,
) {
  final market = arrived.market;
  final awaited = switch (quote) {
    RateLoading(market: final loading) => loading == market,
    RateReady() || RateFailed() => false,
  };
  if (!awaited) return StepNext.stay(state);
  final read = arrived.read;
  return switch (read) {
    ReadGot(:final value) when value.isFinite && value > 0 => StepNext(
      withQuote(RateReady(MarketRate(market, value))),
    ),
    ReadGot() => StepNext(
      withQuote(RateFailed(market, const ReadProblemMalformed())),
    ),
    ReadMissing() || ReadUnreachable() || ReadMalformed() => StepNext(
      withQuote(RateFailed(market, ReadProblem.of(read)!)),
    ),
    ReadSessionRejected() => const StepNext(AmountSessionRejected()),
  };
}

AmountEntryNext transitionAmountEntry(
  AmountPolicy policy,
  AmountEntryState state,
  AmountEntryEvent event,
) => switch ((state, event)) {
  (
    AmountEditing(:final draft, :final quote, :final context),
    AmountTyped(:final text),
  ) =>
    StepNext(
      AmountEditing(
        draft: draft.copyWith(text: text),
        quote: quote,
        context: context,
      ),
    ),
  (
    AmountEditing(:final draft, :final quote, :final context),
    AmountUnitToggled(),
  ) =>
    policy.allowBitcoinUnit
        ? StepNext(
            AmountEditing(
              draft: draft.copyWith(
                text: '',
                unit: switch (draft.unit) {
                  AmountUnit.fiat => AmountUnit.bitcoin,
                  AmountUnit.bitcoin => AmountUnit.fiat,
                },
              ),
              quote: quote,
              context: context,
            ),
          )
        : StepNext.stay(state),
  (
    AmountEditing(:final draft, :final quote, :final context, :final problem),
    AmountDescriptionTyped(:final text),
  ) =>
    policy.withDescription
        ? StepNext(
            AmountEditing(
              draft: draft.copyWith(description: text),
              quote: quote,
              context: context,
              problem: problem,
            ),
          )
        : StepNext.stay(state),
  (
    AmountEditing(:final draft, :final context),
    AmountMarketChosen(:final market),
  ) =>
    market != draft.market && amountMarkets(policy, context).contains(market)
        ? StepNext(
            AmountEditing(
              draft: draft.copyWith(market: market),
              quote: RateLoading(market),
              context: context,
            ),
            [AmountFetchRate(market)],
          )
        : StepNext.stay(state),
  (
    AmountEditing(:final draft, :final quote, :final context, :final problem),
    final AmountRateArrived arrived,
  ) =>
    _onRate(
      state,
      quote,
      arrived,
      (answered) => AmountEditing(
        draft: draft,
        quote: answered,
        context: context,
        problem: problem,
      ),
    ),
  (
    AmountEditing(:final draft, :final quote, :final context),
    AmountRateRetryPressed(),
  ) =>
    switch (quote) {
      RateFailed(:final market) => StepNext(
        AmountEditing(
          draft: draft,
          quote: RateLoading(market),
          context: context,
        ),
        [AmountFetchRate(market)],
      ),
      RateLoading() || RateReady() => StepNext.stay(state),
    },
  (
    AmountEditing(:final draft, :final quote, :final context),
    AmountContinuePressed(),
  ) =>
    switch (checkAmount(policy, draft, quote, context)) {
      AmountCheckPassed(:final amount) => StepNext(AmountDone(amount, context)),
      AmountCheckRefused(:final problem) => StepNext(
        AmountEditing(
          draft: draft,
          quote: quote,
          context: context,
          problem: problem,
        ),
      ),
      AmountCheckKycRequired() => StepNext(AmountKycDetour(draft, quote), [
        AmountOpenKyc(draft.market),
      ]),
      AmountCheckShortfall() => StepNext(AmountFundingDetour(draft, quote), [
        AmountOpenFunding(draft.market),
      ]),
    },
  (
    AmountEditing(),
    AmountDetourReturned() || AmountEditRequested() || AmountLimitRefused(),
  ) =>
    StepNext.stay(state),

  (
    AmountKycDetour(:final draft, :final quote) ||
        AmountFundingDetour(:final draft, :final quote),
    AmountDetourReturned(:final context),
  ) =>
    StepNext(
      AmountEditing(
        draft: draft,
        quote: quote,
        context: context,
        problem: _problemOnReturn(checkAmount(policy, draft, quote, context)),
      ),
    ),
  (
    AmountKycDetour(:final draft, :final quote),
    final AmountRateArrived arrived,
  ) =>
    _onRate(
      state,
      quote,
      arrived,
      (answered) => AmountKycDetour(draft, answered),
    ),
  (
    AmountFundingDetour(:final draft, :final quote),
    final AmountRateArrived arrived,
  ) =>
    _onRate(
      state,
      quote,
      arrived,
      (answered) => AmountFundingDetour(draft, answered),
    ),
  (
    AmountKycDetour() || AmountFundingDetour(),
    AmountTyped() ||
        AmountUnitToggled() ||
        AmountDescriptionTyped() ||
        AmountMarketChosen() ||
        AmountRateRetryPressed() ||
        AmountContinuePressed() ||
        AmountEditRequested() ||
        AmountLimitRefused(),
  ) =>
    StepNext.stay(state),

  (
    AmountDone(:final amount, :final context),
    AmountLimitRefused(:final limit),
  ) =>
    _onLimitRefused(policy, amount, context, limit),
  (AmountDone(:final amount, :final context), AmountEditRequested()) =>
    StepNext(
      AmountEditing(
        draft: amount.draft,
        quote: RateReady(amount.rate),
        context: context,
      ),
    ),
  (
    AmountDone(),
    AmountTyped() ||
        AmountUnitToggled() ||
        AmountDescriptionTyped() ||
        AmountMarketChosen() ||
        AmountRateArrived() ||
        AmountRateRetryPressed() ||
        AmountContinuePressed() ||
        AmountDetourReturned(),
  ) =>
    StepNext.stay(state),

  (AmountNoMarket(), AmountDetourReturned(:final context)) => amountEntryStart(
    policy,
    context,
  ),
  (
    AmountNoMarket(),
    AmountTyped() ||
        AmountUnitToggled() ||
        AmountDescriptionTyped() ||
        AmountMarketChosen() ||
        AmountRateArrived() ||
        AmountRateRetryPressed() ||
        AmountContinuePressed() ||
        AmountEditRequested() ||
        AmountLimitRefused(),
  ) =>
    StepNext.stay(state),

  (
    AmountSessionRejected(),
    AmountTyped() ||
        AmountUnitToggled() ||
        AmountDescriptionTyped() ||
        AmountMarketChosen() ||
        AmountRateArrived() ||
        AmountRateRetryPressed() ||
        AmountContinuePressed() ||
        AmountDetourReturned() ||
        AmountEditRequested() ||
        AmountLimitRefused(),
  ) =>
    StepNext.stay(state),
};
