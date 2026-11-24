import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:test/test.dart';

typedef _Next = StepNext<AmountEntryState, AmountEntryEffect>;

const _cad = ExchangeCatalog.cad;
const _eur = ExchangeCatalog.eur;

const _buy = AmountPolicy(
  currencySource: CurrencyPicker([_cad, _eur]),
  allowBitcoinUnit: true,
  checkBalance: true,
  onShortfall: BalanceShortfall.offerFunding,
  checkKyc: true,
  withDescription: false,
);

const _ctx = AmountContext(
  kycGroups: {KycGroup.identityVerified},
  balances: {FiatCurrency.cad: 500},
);
const _ctx2 = AmountContext(
  kycGroups: {KycGroup.identityVerified},
  balances: {FiatCurrency.cad: 1000},
);

const _rate = MarketRate(_cad, 50000);
const _d = AmountDraft(market: _cad, text: '100');
const _entered = EnteredAmount(
  market: _cad,
  fiat: 100,
  sats: 200000,
  enteredIn: AmountUnit.fiat,
  text: '100',
  rate: _rate,
  description: '',
  overBalance: false,
);
const _unreachable = ReadProblemUnreachable(isNetwork: true);

const _noMarket = AmountNoMarket(_ctx);
const _loading = AmountEditing(
  draft: _d,
  quote: RateLoading(_cad),
  context: _ctx,
);
const _ready = AmountEditing(draft: _d, quote: RateReady(_rate), context: _ctx);
const _failed = AmountEditing(
  draft: _d,
  quote: RateFailed(_cad, _unreachable),
  context: _ctx,
);
const _kyc = AmountKycDetour(_d, RateLoading(_cad));
const _funding = AmountFundingDetour(_d, RateReady(_rate));
const _done = AmountDone(_entered, _ctx);
const _rejected = AmountSessionRejected();

const _states = <AmountEntryState>[
  _noMarket,
  _loading,
  _ready,
  _failed,
  _kyc,
  _funding,
  _done,
  _rejected,
];

const _events = <AmountEntryEvent>[
  AmountTyped('250'),
  AmountUnitToggled(),
  AmountDescriptionTyped('rent'),
  AmountMarketChosen(_eur),
  AmountMarketChosen(_cad),
  AmountMarketChosen(ExchangeCatalog.mxn),
  AmountRateArrived(_cad, ReadGot(50000)),
  AmountRateArrived(_eur, ReadGot(60000)),
  AmountRateArrived(_cad, ReadUnreachable('timeout', isNetwork: true)),
  AmountRateArrived(_cad, ReadSessionRejected(ExchangeSessionRejection.server)),
  AmountRateRetryPressed(),
  AmountContinuePressed(),
  AmountDetourReturned(_ctx2),
  AmountEditRequested(),
];

AmountEditing _editing(
  AmountDraft draft,
  RateQuote quote, {
  AmountContext context = _ctx,
  AmountProblem? problem,
}) => AmountEditing(
  draft: draft,
  quote: quote,
  context: context,
  problem: problem,
);

_Next _to(
  AmountEntryState state, [
  List<AmountEntryEffect> effects = const [],
]) => _Next(state, effects);

const _toEurLoading = _Next(
  AmountEditing(
    draft: AmountDraft(market: _eur, text: '100'),
    quote: RateLoading(_eur),
    context: _ctx,
  ),
  [AmountFetchRate(_eur)],
);

/// null = an explicit stay. One entry per event of [_events], in order.
final _table = <AmountEntryState, List<_Next?>>{
  _noMarket: [
    for (var i = 0; i < 12; i++) null,
    const _Next(
      AmountEditing(
        draft: AmountDraft(market: _cad),
        quote: RateLoading(_cad),
        context: _ctx2,
      ),
      [AmountFetchRate(_cad)],
    ),
    null,
  ],
  _loading: [
    _to(_editing(_d.copyWith(text: '250'), const RateLoading(_cad))),
    _to(
      _editing(
        const AmountDraft(market: _cad, unit: AmountUnit.bitcoin),
        const RateLoading(_cad),
      ),
    ),
    null,
    _toEurLoading,
    null,
    null,
    _to(_ready),
    null,
    _to(_failed),
    const _Next(_rejected),
    null,
    _to(_editing(_d, const RateLoading(_cad), problem: const AmountNoRate())),
    null,
    null,
  ],
  _ready: [
    _to(_editing(_d.copyWith(text: '250'), const RateReady(_rate))),
    _to(
      _editing(
        const AmountDraft(market: _cad, unit: AmountUnit.bitcoin),
        const RateReady(_rate),
      ),
    ),
    null,
    _toEurLoading,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    const _Next(_done),
    null,
    null,
  ],
  _failed: [
    _to(
      _editing(_d.copyWith(text: '250'), const RateFailed(_cad, _unreachable)),
    ),
    _to(
      _editing(
        const AmountDraft(market: _cad, unit: AmountUnit.bitcoin),
        const RateFailed(_cad, _unreachable),
      ),
    ),
    null,
    _toEurLoading,
    null,
    null,
    null,
    null,
    null,
    null,
    const _Next(_loading, [AmountFetchRate(_cad)]),
    _to(
      _editing(
        _d,
        const RateFailed(_cad, _unreachable),
        problem: const AmountNoRate(),
      ),
    ),
    null,
    null,
  ],
  _kyc: [
    null,
    null,
    null,
    null,
    null,
    null,
    const _Next(AmountKycDetour(_d, RateReady(_rate))),
    null,
    const _Next(AmountKycDetour(_d, RateFailed(_cad, _unreachable))),
    const _Next(_rejected),
    null,
    null,
    _to(
      _editing(
        _d,
        const RateLoading(_cad),
        context: _ctx2,
        problem: const AmountNoRate(),
      ),
    ),
    null,
  ],
  _funding: [
    for (var i = 0; i < 12; i++) null,
    _to(_editing(_d, const RateReady(_rate), context: _ctx2)),
    null,
  ],
  _done: [for (var i = 0; i < 13; i++) null, _to(_ready)],
  _rejected: List.filled(_events.length, null),
};

AmountCheck _check(
  String text, {
  AmountPolicy policy = _buy,
  AmountUnit unit = AmountUnit.fiat,
  Market market = _cad,
  RateQuote quote = const RateReady(_rate),
  AmountContext context = _ctx,
  String description = '',
}) => checkAmount(
  policy,
  AmountDraft(market: market, text: text, unit: unit, description: description),
  quote,
  context,
);

AmountPolicy _policy({
  CurrencySource currencySource = const CurrencyPicker([_cad, _eur]),
  bool checkBalance = true,
  BalanceShortfall onShortfall = BalanceShortfall.offerFunding,
  bool checkKyc = true,
  bool withDescription = false,
  AmountLimits? limits,
}) => AmountPolicy(
  currencySource: currencySource,
  allowBitcoinUnit: true,
  checkBalance: checkBalance,
  onShortfall: onShortfall,
  checkKyc: checkKyc,
  withDescription: withDescription,
  limits: limits,
);

void main() {
  group('table', () {
    test('covers every state and event', () {
      expect(_table.keys, _states);
      for (final row in _table.values) {
        expect(row, hasLength(_events.length));
      }
    });

    for (final state in _states) {
      for (final (index, event) in _events.indexed) {
        test('$state + ${event.runtimeType} #$index', () {
          final next = transitionAmountEntry(_buy, state, event);
          final expected = _table[state]![index];
          if (expected == null) {
            expect(identical(next.state, state), isTrue, reason: '$next');
            expect(next.effects, isEmpty);
          } else {
            expect(next, expected);
          }
        });
      }
    }
  });

  group('start', () {
    test('the preferred market when offered, with its rate loading', () {
      expect(
        amountEntryStart(_buy, _ctx, preferred: _eur),
        const _Next(
          AmountEditing(
            draft: AmountDraft(market: _eur),
            quote: RateLoading(_eur),
            context: _ctx,
          ),
          [AmountFetchRate(_eur)],
        ),
      );
    });

    test('the first market when the preferred one is not offered', () {
      expect(
        amountEntryStart(_buy, _ctx, preferred: ExchangeCatalog.mxn).state,
        isA<AmountEditing>().having((s) => s.draft.market, 'market', _cad),
      );
    });

    test('funded balances: only markets with money; none is NoMarket', () {
      final funded = _policy(
        currencySource: const CurrencyFromFundedBalances(),
      );
      const some = AmountContext(
        kycGroups: {},
        balances: {FiatCurrency.cad: 0, FiatCurrency.eur: 10},
      );
      expect(amountMarkets(funded, some), [_eur]);
      const none = AmountContext(kycGroups: {}, balances: {});
      expect(amountEntryStart(funded, none), const _Next(AmountNoMarket(none)));
    });

    test('a fixed market is the only one', () {
      final fixed = _policy(currencySource: const CurrencyFixed(_eur));
      expect(amountMarkets(fixed, _ctx), [_eur]);
      expect(
        transitionAmountEntry(
          fixed,
          _editing(const AmountDraft(market: _eur), const RateLoading(_eur)),
          const AmountMarketChosen(_cad),
        ).effects,
        isEmpty,
      );
    });
  });

  group('checkAmount', () {
    test('text that is not a positive amount with the currency decimals', () {
      for (final text in ['', 'abc', '0', '0.00', '1.234', '-5', '1,5', '.5']) {
        expect(
          _check(text),
          const AmountCheckRefused(AmountInvalid()),
          reason: text,
        );
      }
    });

    test('COP has no decimals', () {
      const cop = ExchangeCatalog.cop;
      const copRate = RateReady(MarketRate(cop, 400000000));
      const copCtx = AmountContext(
        kycGroups: {KycGroup.identityVerified},
        balances: {FiatCurrency.cop: 1000000},
      );
      expect(
        _check('1.5', market: cop, quote: copRate, context: copCtx),
        const AmountCheckRefused(AmountInvalid()),
      );
      expect(
        _check('1500', market: cop, quote: copRate, context: copCtx),
        isA<AmountCheckPassed>(),
      );
    });

    test('a rate of another market, or none, refuses Continue', () {
      expect(
        _check('100', quote: const RateReady(MarketRate(_eur, 60000))),
        const AmountCheckRefused(AmountNoRate()),
      );
      expect(
        _check('100', quote: const RateLoading(_cad)),
        const AmountCheckRefused(AmountNoRate()),
      );
    });

    test('bitcoin entry is converted and checked on its fiat value', () {
      expect(
        _check('0.001', unit: AmountUnit.bitcoin),
        const AmountCheckPassed(
          EnteredAmount(
            market: _cad,
            fiat: 50,
            sats: 100000,
            enteredIn: AmountUnit.bitcoin,
            text: '0.001',
            rate: _rate,
            description: '',
            overBalance: false,
          ),
        ),
      );
      expect(
        _check('0.000000001', unit: AmountUnit.bitcoin),
        const AmountCheckRefused(AmountInvalid()),
      );
      expect(
        _check(
          '0.02',
          unit: AmountUnit.bitcoin,
          context: const AmountContext(
            kycGroups: {},
            balances: {FiatCurrency.cad: 5000},
          ),
        ),
        const AmountCheckKycRequired(),
      );
    });

    test('limits', () {
      final limited = _policy(
        limits: const AmountLimits(minFiat: 10, maxFiat: 200),
      );
      expect(
        _check('5', policy: limited),
        const AmountCheckRefused(AmountBelowMinimum(10)),
      );
      expect(
        _check('300', policy: limited),
        const AmountCheckRefused(AmountAboveMaximum(200)),
      );
      expect(_check('150', policy: limited), isA<AmountCheckPassed>());
    });

    test("the market's KYC policy decides", () {
      const none = AmountContext(
        kycGroups: {},
        balances: {FiatCurrency.cad: 5000},
      );
      const limited = AmountContext(
        kycGroups: {KycGroup.limited},
        balances: {FiatCurrency.cad: 5000},
      );
      expect(_check('10', context: none), const AmountCheckKycRequired());
      expect(_check('1000', context: limited), const AmountCheckKycRequired());
      expect(_check('999', context: limited), isA<AmountCheckPassed>());
      expect(
        _check('10', context: none, policy: _policy(checkKyc: false)),
        isA<AmountCheckPassed>(),
      );
    });

    test('over the balance follows the policy', () {
      expect(
        _check('600', policy: _policy(onShortfall: BalanceShortfall.block)),
        const AmountCheckRefused(AmountOverBalance(500)),
      );
      expect(_check('600'), const AmountCheckShortfall(500));
      expect(
        _check('600', policy: _policy(onShortfall: BalanceShortfall.warn)),
        isA<AmountCheckPassed>().having(
          (c) => c.amount.overBalance,
          'overBalance',
          isTrue,
        ),
      );
      expect(
        _check('600', policy: _policy(checkBalance: false)),
        isA<AmountCheckPassed>().having(
          (c) => c.amount.overBalance,
          'overBalance',
          isFalse,
        ),
      );
    });

    test('the description is kept only when the policy asks for one', () {
      expect(
        _check('100', description: 'rent'),
        isA<AmountCheckPassed>().having(
          (c) => c.amount.description,
          'description',
          '',
        ),
      );
      expect(
        _check(
          '100',
          description: 'rent',
          policy: _policy(withDescription: true),
        ),
        isA<AmountCheckPassed>().having(
          (c) => c.amount.description,
          'description',
          'rent',
        ),
      );
    });
  });

  group('detours', () {
    test('KYC required opens the KYC view over the flow with the draft', () {
      const noKyc = AmountContext(
        kycGroups: {},
        balances: {FiatCurrency.cad: 500},
      );
      expect(
        transitionAmountEntry(
          _buy,
          _editing(_d, const RateReady(_rate), context: noKyc),
          const AmountContinuePressed(),
        ),
        const _Next(AmountKycDetour(_d, RateReady(_rate)), [
          AmountOpenKyc(_cad),
        ]),
      );
    });

    test('a shortfall offers funding with the draft', () {
      const draft = AmountDraft(market: _cad, text: '600');
      expect(
        transitionAmountEntry(
          _buy,
          _editing(draft, const RateReady(_rate)),
          const AmountContinuePressed(),
        ),
        const _Next(AmountFundingDetour(draft, RateReady(_rate)), [
          AmountOpenFunding(_cad),
        ]),
      );
    });

    test('returning re-checks the same draft against the new context', () {
      const noKyc = AmountContext(
        kycGroups: {},
        balances: {FiatCurrency.cad: 500},
      );
      expect(
        transitionAmountEntry(
          _buy,
          const AmountKycDetour(_d, RateReady(_rate)),
          const AmountDetourReturned(noKyc),
        ),
        _to(
          _editing(
            _d,
            const RateReady(_rate),
            context: noKyc,
            problem: const AmountKycNeeded(),
          ),
        ),
      );
      const big = AmountDraft(market: _cad, text: '600');
      expect(
        transitionAmountEntry(
          _buy,
          const AmountFundingDetour(big, RateReady(_rate)),
          const AmountDetourReturned(_ctx),
        ),
        _to(
          _editing(
            big,
            const RateReady(_rate),
            problem: const AmountOverBalance(500),
          ),
        ),
      );
    });
  });

  test('an unreadable rate value is a failed rate', () {
    expect(
      transitionAmountEntry(
        _buy,
        _loading,
        const AmountRateArrived(_cad, ReadGot(0)),
      ),
      _to(_editing(_d, const RateFailed(_cad, ReadProblemMalformed()))),
    );
  });

  test('every state is reachable', () {
    final funded = _policy(currencySource: const CurrencyFromFundedBalances());
    const empty = AmountContext(kycGroups: {}, balances: {});
    const noKyc = AmountContext(
      kycGroups: {},
      balances: {FiatCurrency.cad: 1000},
    );
    const events = <AmountEntryEvent>[
      AmountTyped('250'),
      AmountTyped('5000'),
      AmountRateArrived(_cad, ReadGot(50000)),
      AmountRateArrived(
        _cad,
        ReadSessionRejected(ExchangeSessionRejection.server),
      ),
      AmountContinuePressed(),
      AmountDetourReturned(noKyc),
      AmountDetourReturned(_ctx2),
      AmountEditRequested(),
    ];
    final start = amountEntryStart(funded, empty).state;
    final seen = <AmountEntryState>{start};
    var frontier = [start];
    while (frontier.isNotEmpty) {
      final next = <AmountEntryState>[];
      for (final state in frontier) {
        for (final event in events) {
          final target = transitionAmountEntry(funded, state, event).state;
          if (seen.add(target)) next.add(target);
        }
      }
      frontier = next;
    }
    expect(
      {for (final state in seen) state.runtimeType},
      {for (final state in _states) state.runtimeType},
    );
  });
}
