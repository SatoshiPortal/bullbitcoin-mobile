import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:exchange/testing.dart';
import 'package:test/test.dart';

typedef _S = PayinState<String>;
typedef _E = PayinEvent<String>;
typedef _F = PayinEffect<String>;
typedef _Next = StepNext<_S, _F>;

final _message = OrderMessage(code: '', message: '');
final _deadline = DateTime.utc(2026, 11, 24, 12);
final _before = DateTime.utc(2026, 11, 24, 11);
final _after = DateTime.utc(2026, 11, 24, 13);

Order _order({
  OrderPayinStatus payinStatus = OrderPayinStatus.awaitingPayment,
  OrderStatus orderStatus = OrderStatus.inProgress,
  OrderPaymentMethod payinMethod = OrderPaymentMethod.bitcoin,
  String? address = 'tb1q',
  String? invoice,
  DateTime? deadline,
}) => Order.sell(
  orderId: 'o-1',
  orderType: OrderType.sell,
  message: _message,
  orderNumber: 1,
  payinAmount: 0.001,
  payinCurrency: 'BTC',
  payoutAmount: 100,
  payoutCurrency: 'CAD',
  payinMethod: payinMethod,
  payoutMethod: OrderPaymentMethod.cadBalance,
  orderStatus: orderStatus,
  payinStatus: payinStatus,
  payoutStatus: OrderPayoutStatus.notStarted,
  confirmationDeadline: deadline ?? _deadline,
  createdAt: DateTime.utc(2026, 11, 24, 10),
  bitcoinAddress: address,
  lightningInvoice: invoice,
  isTestnet: true,
);

final _o = _order();
final _seen = _order(payinStatus: OrderPayinStatus.awaitingConfirmation);
final _ended = _order(orderStatus: OrderStatus.expired);
final _moved = _order(address: 'tb1moved');

const _t = OnchainDeposit('tb1q');
const _built = PayinBuilt<String>('w1', 'tx1', 'signed');
const _policy = PayinPolicy(
  maxPolls: 3,
  maxDuration: Duration(minutes: 30),
  maxUnreadable: 2,
);
const _busy = WriteGateBusy(FinancialWriteKind.orderConfirm);
const _unreachable = ReadProblemUnreachable(isNetwork: true);

UnknownWrite _entry(String id, UnknownWriteKind kind, String? orderId) =>
    UnknownWrite(
      id: id,
      kind: kind,
      environment: ExchangeEnvironment.mainnet,
      request: {'orderId': ?orderId, 'txid': 'tx-journal'},
      recordedAt: DateTime.utc(2026, 11, 24),
      orderId: orderId,
    );

final _ownEntry = _entry('e1', UnknownWriteKind.payin, 'o-1');
final _otherEntry = _entry('e2', UnknownWriteKind.buyConfirm, 'o-9');

WatchWatching<Order> _w(Order order) => WatchWatching<Order>(order, 0, 0, 1);

final _building = PayinBuilding<String>(_o, _t, 'w1', 1);
final _broadcasting = PayinBroadcasting<String>(_o, _t, 1, _built);
final _writeRefused = PayinWriteRefused<String>(_o, _t, 1, _built, _busy);
final _sendFailed = PayinSendFailed<String>(
  _o,
  _t,
  1,
  const PayinResumeBuild('w1'),
  const PayinBuildRefused(PayinBuildProblem.insufficientFunds),
);
final _rechecking = PayinRechecking<String>(
  _o,
  _t,
  2,
  const PayinResumeBuild('w1'),
);
final _recheckFailed = PayinRecheckFailed<String>(
  _o,
  _t,
  2,
  const PayinResumeBuild('w1'),
  _unreachable,
);
final _negotiating = PayinPayjoinNegotiating<String>(_o, _t, 1, 's1', 'otx');
final _paused = PayinPayjoinPaused<String>(_o, _t, 1, 's1', 'otx');
final _verifying = PayinVerifying<String>(_o, _t, 1, 'tx1', _built);
final _unseen = PayinUnseen<String>(_o, _t, 1, 'tx1', _built);
final _unseenNothingHeld = PayinUnseen<String>(_o, _t, 1, 'otx', null);
final _unverified = PayinUnverified<String>(
  _o,
  _t,
  1,
  'tx1',
  _built,
  _unreachable,
);
final _watching = PayinWatching<String>(_o, _t, 'tx1', _w(_o));
final _external = PayinExternal<String>(_o, _t, _w(_o));
final _leaving = PayinExternalLeaving<String>(_o, _t, _w(_o));
final _completed = PayinCompleted<String>(_seen, 'tx1');
final _refused = PayinRefusedByExchange<String>(_ended, 'tx1');
final _lapsed = PayinQuoteLapsed<String>(_o);
final _orderEnded = PayinOrderEnded<String>(_ended);
final _depositRefused = PayinDepositRefused<String>(_moved);
const _left = PayinLeft<String>();
final _leftPending = PayinLeftPending<String>(_o, 'tx1');
const _sessionEnded = PayinSessionEnded<String>();

final _states = <_S>[
  _building, // 0
  _broadcasting, // 1
  _writeRefused, // 2
  _sendFailed, // 3
  _rechecking, // 4
  _recheckFailed, // 5
  _negotiating, // 6
  _paused, // 7
  _verifying, // 8
  _unseen, // 9
  _unseenNothingHeld, // 10
  _unverified, // 11
  _watching, // 12
  _external, // 13
  _leaving, // 14
  _completed, // 15
  _refused, // 16
  _lapsed, // 17
  _orderEnded, // 18
  _depositRefused, // 19
  _left, // 20
  _leftPending, // 21
  _sessionEnded, // 22
];

const _rejected = ReadSessionRejected<Order>(ExchangeSessionRejection.server);

final _events = <_E>[
  PayinBuildAnswered(1, const PayinBuildOk(_built), _before), // 0
  PayinBuildAnswered(1, const PayinBuildOk(_built), _after), // 1
  PayinBuildAnswered(
    1,
    const PayinBuildFailed(PayinBuildProblem.insufficientFunds),
    _before,
  ), // 2
  PayinBuildAnswered(2, const PayinBuildOk(_built), _before), // 3
  const PayinSendAnswered(1, GateAdmitted(PayinBroadcastAccepted('tx1'))), // 4
  const PayinSendAnswered(
    1,
    GateAdmitted(PayinHandedToPayjoin('s1', 'otx')),
  ), // 5
  const PayinSendAnswered(
    1,
    GateAdmitted(PayinBroadcastRefused(PayinRefusal.nodeRejected)),
  ), // 6
  const PayinSendAnswered(
    1,
    GateAdmitted(PayinBroadcastNotSent(PayinNotSentReason.walletBusy)),
  ), // 7
  const PayinSendAnswered(
    1,
    GateAdmitted(PayinBroadcastNotSent(PayinNotSentReason.deadlinePassed)),
  ), // 8
  const PayinSendAnswered(1, GateAdmitted(PayinBroadcastOutcomeUnknown(null))),
  // 9
  const PayinSendAnswered(1, GateRefused(_busy)), // 10
  PayinSendAnswered(1, GateRefused(WriteGateUnsettled(_ownEntry))), // 11
  PayinSendAnswered(1, GateRefused(WriteGateUnsettled(_otherEntry))), // 12
  const PayinSendAnswered(2, GateAdmitted(PayinBroadcastAccepted('tx1'))), // 13
  PayinRechecked(2, ReadGot(_o), _before), // 14
  PayinRechecked(2, ReadGot(_seen), _before), // 15
  PayinRechecked(2, ReadGot(_ended), _before), // 16
  PayinRechecked(2, ReadGot(_moved), _before), // 17
  PayinRechecked(2, ReadGot(_o), _after), // 18
  PayinRechecked(2, const ReadUnreachable('down', isNetwork: true), _before),
  // 19
  PayinRechecked(2, _rejected, _before), // 20
  PayinRechecked(1, ReadGot(_o), _before), // 21
  const PayinVerified(1, PayinCheckSeenOnNetwork('tx1')), // 22
  PayinVerified(1, PayinCheckSeenByExchange(_seen)), // 23
  const PayinVerified(1, PayinCheckNotSeen()), // 24
  const PayinVerified(1, PayinCheckFailed(_unreachable)), // 25
  const PayinVerified(1, PayinCheckSessionRejected()), // 26
  const PayinVerified(2, PayinCheckNotSeen()), // 27
  const PayinPayjoinUpdated('s1', PayjoinNegotiating()), // 28
  const PayinPayjoinUpdated('s1', PayjoinPaused()), // 29
  const PayinPayjoinUpdated('s1', PayjoinSent('pjtx')), // 30
  const PayinPayjoinUpdated('s1', PayjoinExpired()), // 31
  const PayinPayjoinUpdated('s9', PayjoinSent('x')), // 32
  const PayinPayjoinWatchEnded('s1'), // 33
  const PayinPayjoinWatchEnded('s9'), // 34
  PayinWatchEvent(WatchPolled('o-1', 1, ReadGot(_seen))), // 35
  PayinWatchEvent(WatchPolled('o-1', 1, ReadGot(_ended))), // 36
  const PayinWatchEvent(WatchVisibilityChanged(visible: false)), // 37
  const PayinWatchEvent(WatchLeavePressed()), // 38
  PayinWatchEvent(WatchPolled('o-1', 9, ReadGot(_seen))), // 39
  const PayinRetryPressed(), // 40
  const PayinResendPressed(), // 41
  const PayinBackPressed(), // 42
  const PayinLeaveConfirmed(), // 43
  const PayinLeaveCancelled(), // 44
];

const _stop = PayinWatchEffect<String>(WatchStop('o-1'));
const _cancelPoll = PayinWatchEffect<String>(WatchCancelPoll('o-1'));
const _watchStart = [
  PayinWatchEffect<String>(WatchStartDeadline('o-1', Duration(minutes: 30))),
  PayinWatchEffect<String>(WatchSchedulePoll('o-1', 1)),
];

_Next _toWatching(String? txid, [List<_F> before = const []]) =>
    _Next(PayinWatching(_o, _t, txid, _w(_o)), [...before, ..._watchStart]);

final _toVerifying = _Next(_verifying, [PayinVerify(_o, _t, 1, 'tx1')]);
final _toPayjoinVerify = _Next(PayinVerifying(_o, _t, 1, 'otx', null), [
  PayinVerify(_o, _t, 1, 'otx'),
]);
final _toPayjoinExpired = _Next(PayinVerifying(_o, _t, 1, 'otx', null), [
  const PayinStopPayjoin('s1'),
  PayinVerify(_o, _t, 1, 'otx'),
]);
final _toRebuildCheck = _Next(_rechecking, [const PayinRecheck('o-1', 2)]);
final _toResendCheck = _Next(
  PayinRechecking(_o, _t, 2, const PayinResumeSend(_built)),
  [const PayinRecheck('o-1', 2)],
);

/// The transitions; every (state, event) pair not listed is a stay.
final _table = <_S, Map<int, _Next>>{
  _building: {
    0: _Next(_broadcasting, [PayinSend(_o, _t, 1, _built)]),
    1: _Next(_lapsed),
    2: _Next(_sendFailed),
    42: const _Next(_left),
  },
  _broadcasting: {
    4: _toWatching('tx1'),
    5: _Next(_negotiating, [const PayinFollowPayjoin('s1')]),
    6: _Next(
      PayinSendFailed(
        _o,
        _t,
        1,
        const PayinResumeBuild('w1'),
        const PayinSendRefused(PayinRefusal.nodeRejected),
      ),
    ),
    7: _Next(
      PayinSendFailed(
        _o,
        _t,
        1,
        const PayinResumeSend(_built),
        const PayinSendNotSent(PayinNotSentReason.walletBusy),
      ),
    ),
    8: _Next(_lapsed),
    9: _toVerifying,
    10: _Next(_writeRefused),
    11: _toVerifying,
    12: _Next(
      PayinWriteRefused(_o, _t, 1, _built, WriteGateUnsettled(_otherEntry)),
    ),
  },
  _writeRefused: {40: _toResendCheck, 42: const _Next(_left)},
  _sendFailed: {40: _toRebuildCheck, 42: const _Next(_left)},
  _rechecking: {
    14: _Next(PayinBuilding(_o, _t, 'w1', 2), [PayinBuild(_o, _t, 'w1', 2)]),
    15: _Next(PayinCompleted(_seen, null)),
    16: _Next(_orderEnded),
    17: _Next(_depositRefused),
    18: _Next(_lapsed),
    19: _Next(_recheckFailed),
    20: const _Next(_sessionEnded),
  },
  _recheckFailed: {40: _toRebuildCheck, 42: const _Next(_left)},
  _negotiating: {
    29: _Next(_paused),
    30: _toWatching('pjtx', [const PayinStopPayjoin('s1')]),
    31: _toPayjoinExpired,
    33: _toPayjoinVerify,
  },
  _paused: {
    28: _Next(_negotiating),
    30: _toWatching('pjtx', [const PayinStopPayjoin('s1')]),
    31: _toPayjoinExpired,
    33: _toPayjoinVerify,
    40: _Next(_negotiating, [const PayinRetryPayjoin('s1')]),
  },
  _verifying: {
    22: _toWatching('tx1'),
    23: _Next(PayinCompleted(_seen, 'tx1')),
    24: _Next(_unseen),
    25: _Next(_unverified),
    26: const _Next(_sessionEnded),
  },
  _unseen: {40: _toVerifying, 41: _toResendCheck, 42: _Next(_leftPending)},
  _unseenNothingHeld: {
    40: _toPayjoinVerify,
    42: _Next(PayinLeftPending(_o, 'otx')),
  },
  _unverified: {40: _toVerifying, 42: _Next(_leftPending)},
  _watching: {
    35: _Next(_completed, [_stop]),
    36: _Next(_refused, [_stop]),
    37: _Next(PayinWatching(_o, _t, 'tx1', WatchPaused<Order>(_o, 0, 0, 2)), [
      _cancelPoll,
    ]),
    38: _Next(_leftPending, [_stop]),
    42: _Next(_leftPending, [_stop]),
  },
  _external: {
    35: _Next(PayinCompleted(_seen, null), [_stop]),
    36: _Next(PayinRefusedByExchange(_ended, null), [_stop]),
    37: _Next(PayinExternal(_o, _t, WatchPaused<Order>(_o, 0, 0, 2)), [
      _cancelPoll,
    ]),
    38: _Next(PayinLeftPending(_o, null), [_stop]),
    42: _Next(_leaving),
  },
  _leaving: {
    35: _Next(PayinCompleted(_seen, null), [_stop]),
    36: _Next(PayinRefusedByExchange(_ended, null), [_stop]),
    37: _Next(PayinExternalLeaving(_o, _t, WatchPaused<Order>(_o, 0, 0, 2)), [
      _cancelPoll,
    ]),
    38: _Next(PayinLeftPending(_o, null), [_stop]),
    42: _Next(_external),
    43: _Next(PayinLeftPending(_o, null), [_stop]),
    44: _Next(_external),
  },
  _completed: {},
  _refused: {},
  _lapsed: {},
  _orderEnded: {},
  _depositRefused: {},
  _left: {},
  _leftPending: {},
  _sessionEnded: {},
};

_Next _start(
  Order order,
  PayinSource source, {
  DateTime? now,
  UnknownWrite? openEntry,
}) => payinStart<String>(
  _policy,
  order: order,
  source: source,
  now: now ?? _before,
  openEntry: openEntry,
);

void main() {
  test('the table has a row for every state', () {
    expect(_table.keys, _states);
  });

  for (final (stateIndex, state) in _states.indexed) {
    for (final (index, event) in _events.indexed) {
      test(
        '#$stateIndex ${state.runtimeType} + ${event.runtimeType} #$index',
        () {
          final next = transitionPayin(_policy, state, event);
          final expected = _table[state]![index];
          if (expected == null) {
            expect(identical(next.state, state), isTrue, reason: '$next');
            expect(next.effects, isEmpty);
          } else {
            expect(next, expected);
          }
        },
      );
    }
  }

  group('start', () {
    const wallet = PayinFromAppWallet('w1', BtcNetwork.bitcoin);
    const external = PayinFromExternal(BtcNetwork.bitcoin);

    test('an app wallet builds', () {
      expect(
        _start(_o, wallet),
        _Next(_building, [PayinBuild(_o, _t, 'w1', 1)]),
      );
    });

    test('an external payin shows the deposit and watches the order', () {
      expect(_start(_o, external), _Next(_external, _watchStart));
    });

    test('an open payin entry of the order verifies, never sends', () {
      final open = openPayinEntryFor('o-1', [_otherEntry, _ownEntry]);
      expect(open, _ownEntry);
      expect(
        _start(_o, wallet, openEntry: open),
        _Next(PayinVerifying(_o, _t, 1, 'tx-journal', null), [
          PayinVerify(_o, _t, 1, 'tx-journal'),
        ]),
      );
      expect(openPayinEntryFor('o-1', [_otherEntry]), isNull);
    });

    test('a payin the exchange already shows is watched, not sent', () {
      expect(_start(_seen, wallet), _Next(PayinCompleted(_seen, null)));
      final unknown = _order(payinStatus: OrderPayinStatus.unknown);
      expect(
        _start(unknown, wallet),
        _Next(PayinWatching(unknown, _t, null, _w(unknown)), _watchStart),
      );
    });

    test('an ended order or a lapsed deadline sends nothing', () {
      expect(_start(_ended, wallet), _Next(_orderEnded));
      expect(_start(_o, wallet, now: _after), _Next(_lapsed));
      expect(_start(_o, wallet, now: _deadline), _Next(_lapsed));
    });

    test('no deposit on the source rail is refused', () {
      expect(
        _start(_order(address: null), wallet),
        _Next(PayinDepositRefused(_order(address: null))),
      );
      expect(
        _start(_o, const PayinFromAppWallet('w2', BtcNetwork.liquid)),
        _Next(PayinDepositRefused(_o)),
      );
    });

    test('a Lightning order pays its invoice from outside (PAY-1)', () {
      final ln = _order(
        payinMethod: OrderPaymentMethod.lnInvoice,
        address: null,
        invoice: 'lntb1',
      );
      final next = _start(ln, const PayinFromExternal(BtcNetwork.lightning));
      expect(
        next.state,
        PayinExternal<String>(
          ln,
          const LightningInvoiceDeposit('lntb1'),
          _w(ln),
        ),
      );
      expect(
        _start(ln, const PayinFromAppWallet('w1', BtcNetwork.lightning)),
        _Next(PayinDepositRefused(ln)),
      );
    });
  });

  group('payin verdict', () {
    final table = {
      OrderPayinStatus.notStarted: OutcomeVerdict.pending,
      OrderPayinStatus.awaitingPayment: OutcomeVerdict.pending,
      OrderPayinStatus.inProgress: OutcomeVerdict.done,
      OrderPayinStatus.underReview: OutcomeVerdict.done,
      OrderPayinStatus.awaitingConfirmation: OutcomeVerdict.done,
      OrderPayinStatus.completed: OutcomeVerdict.done,
      OrderPayinStatus.rejected: OutcomeVerdict.failed,
      OrderPayinStatus.unknown: OutcomeVerdict.pending,
    };

    test('names every payin status', () {
      expect(table.keys, containsAll(OrderPayinStatus.values));
    });

    for (final MapEntry(key: status, value: verdict) in table.entries) {
      test('$status -> $verdict', () {
        expect(payinVerdict(_t, _order(payinStatus: status)), verdict);
      });
    }

    test('an order that ended or moved its deposit unpaid failed', () {
      expect(payinVerdict(_t, _ended), OutcomeVerdict.failed);
      expect(payinVerdict(_t, _moved), OutcomeVerdict.failed);
      expect(
        payinVerdict(
          _t,
          _order(
            orderStatus: OrderStatus.expired,
            payinStatus: OrderPayinStatus.completed,
          ),
        ),
        OutcomeVerdict.done,
      );
    });
  });

  test('payin options come from the rails', () {
    expect(
      payinOptionsFor({
        'btc': BtcNetwork.bitcoin,
        'lbtc': BtcNetwork.liquid,
        'ln': BtcNetwork.lightning,
      }),
      const [
        PayinOptionAppWallet('btc', BtcNetwork.bitcoin),
        PayinOptionAppWallet('lbtc', BtcNetwork.liquid),
        PayinOptionExternal(BtcNetwork.bitcoin),
        PayinOptionExternal(BtcNetwork.liquid),
        PayinOptionExternal(BtcNetwork.lightning),
      ],
    );
  });

  test('a completed payin is a payin-seen commit', () {
    expect(_completed.committed, PayinSeen<Order>(_seen, 'tx1'));
  });

  test('every state is reachable from the starts', () {
    final reached = <Type>{};
    final seen = <_S>{};
    var frontier = <_S>[
      _start(_o, const PayinFromAppWallet('w1', BtcNetwork.bitcoin)).state,
      _start(_o, const PayinFromExternal(BtcNetwork.bitcoin)).state,
      _start(
        _o,
        const PayinFromAppWallet('w1', BtcNetwork.bitcoin),
        openEntry: _ownEntry,
      ).state,
    ];
    seen.addAll(frontier);
    for (final state in frontier) {
      reached.add(state.runtimeType);
    }
    while (frontier.isNotEmpty) {
      final next = <_S>[];
      for (final state in frontier) {
        for (final event in _events) {
          final target = transitionPayin(_policy, state, event).state;
          reached.add(target.runtimeType);
          if (seen.add(target)) next.add(target);
        }
      }
      frontier = next;
    }
    expect(reached, {for (final state in _states) state.runtimeType});
  });

  group('runPayinSend', () {
    const session = ExchangeSession(
      environment: ExchangeEnvironment.mainnet,
      epoch: 1,
      sessionId: 's',
    );
    final effect = PayinSend<String>(_o, _t, 1, _built);
    late List<(String, BtcNetwork, String?)> journaled;
    late List<String> sent;

    setUp(() {
      journaled = [];
      sent = [];
    });

    Future<PayinSendAnswered<String>> run(
      ExchangeWriteGate gate,
      Future<PayinBroadcastOutcome> Function() answer, {
      DateTime? now,
    }) => runPayinSend<String>(
      gate: gate,
      session: session,
      effect: effect,
      now: () => now ?? _before,
      send: (built) {
        sent.add(built.payload);
        return answer();
      },
      journalUnknown: (orderId, network, txid) async =>
          journaled.add((orderId, network, txid)),
    );

    test('sends through the gate as the payin write', () async {
      final answered = await run(
        ExchangeWriteGate(),
        () async => const PayinBroadcastAccepted('tx1'),
      );
      expect(answered.attempt, 1);
      expect(
        answered.answer,
        isA<GateAdmitted<PayinBroadcastOutcome>>().having(
          (a) => a.result,
          'result',
          const PayinBroadcastAccepted('tx1'),
        ),
      );
      expect(sent, ['signed']);
      expect(journaled, isEmpty);
    });

    test('an unknown outcome is journaled before it is answered', () async {
      final answered = await run(
        ExchangeWriteGate(),
        () async => const PayinBroadcastOutcomeUnknown(null),
      );
      expect(journaled, [('o-1', BtcNetwork.bitcoin, 'tx1')]);
      expect(
        transitionPayin(_policy, _broadcasting, answered).state,
        _verifying,
      );
    });

    test('a send that throws counts as unknown and is journaled', () async {
      final answered = await run(
        ExchangeWriteGate(),
        () async => throw StateError('relay died'),
      );
      expect(
        answered.answer,
        isA<GateAdmitted<PayinBroadcastOutcome>>().having(
          (a) => a.result,
          'result',
          const PayinBroadcastOutcomeUnknown('tx1'),
        ),
      );
      expect(journaled, [('o-1', BtcNetwork.bitcoin, 'tx1')]);
    });

    test('past the order deadline nothing is sent', () async {
      final answered = await run(
        ExchangeWriteGate(),
        () async => const PayinBroadcastAccepted('tx1'),
        now: _deadline,
      );
      expect(sent, isEmpty);
      expect(transitionPayin(_policy, _broadcasting, answered).state, _lapsed);
    });

    test('an unsettled payin of this order verifies instead', () async {
      final journal = InMemoryUnknownWriteJournal();
      final _ = await journal.record(
        const UnknownWriteDraft(
          kind: UnknownWriteKind.payin,
          environment: ExchangeEnvironment.mainnet,
          orderId: 'o-1',
          request: {'orderId': 'o-1'},
        ),
      );
      final answered = await run(
        ExchangeWriteGate(journal: journal),
        () async => const PayinBroadcastAccepted('tx1'),
      );
      expect(sent, isEmpty);
      expect(transitionPayin(_policy, _broadcasting, answered), _toVerifying);
    });

    test('a write in flight is an explicit refusal, nothing sent', () async {
      final gate = ExchangeWriteGate();
      final held = gate.run(
        session,
        FinancialWriteKind.orderConfirm,
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      final answered = await run(
        gate,
        () async => const PayinBroadcastAccepted('tx1'),
      );
      await held;
      expect(sent, isEmpty);
      expect(
        transitionPayin(_policy, _broadcasting, answered).state,
        _writeRefused,
      );
    });
  });
}
