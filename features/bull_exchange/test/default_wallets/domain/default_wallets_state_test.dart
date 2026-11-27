import 'package:bull_exchange/src/default_wallets/domain/default_wallets_state.dart';
import 'package:bull_exchange/src/default_wallets/domain/default_wallets_event.dart';
import 'package:bull_exchange/src/default_wallets/domain/default_wallets_effect.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

const _s = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 's',
);
const _btc = BtcNetwork.bitcoin;
const _saved = DefaultWallets(
  bitcoin: DefaultWallet(
    recipientId: 'r1',
    walletType: BtcNetwork.bitcoin,
    address: 'bc1qsaved',
  ),
);
const _newWallet = DefaultWallet(
  recipientId: 'r1',
  walletType: BtcNetwork.bitcoin,
  address: 'bc1qnorm',
);
const _withNew = DefaultWallets(bitcoin: _newWallet);
const _netDown = Err<DefaultWallets, ExchangeReadFailure>(
  ExchangeUnreachableFailure('down', isNetwork: true),
);
const _serverDown = Err<DefaultWallets, ExchangeReadFailure>(
  ExchangeUnreachableFailure('500', isNetwork: false),
);
const _rejected = Err<DefaultWallets, ExchangeReadFailure>(
  ExchangeSessionRejectedFailure(ExchangeSessionRejection.server),
);
const _saveIntent = SlotSaveIntent(draft: 'bc1qnew', address: 'bc1qnorm');
final _entry = UnknownWrite(
  id: 'j1',
  kind: UnknownWriteKind.defaultWalletSave,
  environment: ExchangeEnvironment.mainnet,
  request: const {},
  recordedAt: DateTime(2026),
);

WalletsReady _ready(
  WalletSlot bitcoin, {
  WalletSlot lightning = const SlotShowing(),
  DefaultWallets saved = _saved,
  int attempts = 5,
}) => WalletsReady(
  _s,
  saved,
  slots: WalletSlots(bitcoin: bitcoin, lightning: lightning),
  attempts: attempts,
);

const _lnSaving = SlotSaving('ln', 'sat@example.com', 5);

/// One state of each shape the table distinguishes.
final _states = <DefaultWalletsState>[
  const WalletsLoading(_s, 1), // 0
  const WalletsLoadFailed(_s, 1, ReadProblemUnreachable(isNetwork: true)), // 1
  const WalletsSessionEnded(), // 2
  _ready(const SlotShowing()), // 3
  _ready(const SlotEditing('bc1qnew')), // 4
  _ready(const SlotEditing('  ')), // 5
  _ready(const SlotChecking('bc1qnew', 5)), // 6
  _ready(const SlotSaving('bc1qnew', 'bc1qnorm', 5)), // 7
  _ready(const SlotUnsetting(5)), // 8
  _ready(const SlotVerifying(_saveIntent, 5)), // 9
  _ready(
    const SlotUnverified(_saveIntent, ReadProblemUnreachable(isNetwork: false)),
  ), // 10
  _ready(const SlotEditing('bc1qnew'), lightning: _lnSaving), // 11
];

GatedWrite<Result<DefaultWallet, ExchangeWriteFailure>> _saveAnswer(
  Result<DefaultWallet, ExchangeWriteFailure> write,
) => GateAdmitted(write);

/// Per event, the states that change (by index into [_states]) and what they
/// become. Every other state stays (same instance, no effects).
final _table = <String, (DefaultWalletsEvent, Map<int, DefaultWalletsState>)>{
  'loaded': (
    const WalletsLoaded(1, Ok(_saved)),
    {0: const WalletsReady(_s, _saved, attempts: 1)},
  ),
  'loaded, stale attempt': (const WalletsLoaded(2, Ok(_saved)), {}),
  'load unreachable (never empty wallets)': (
    const WalletsLoaded(1, _netDown),
    {
      0: const WalletsLoadFailed(
        _s,
        1,
        ReadProblemUnreachable(isNetwork: true),
      ),
    },
  ),
  'load rejected': (
    const WalletsLoaded(1, _rejected),
    {0: const WalletsSessionEnded()},
  ),
  'retry': (const WalletsRetryPressed(), {1: const WalletsLoading(_s, 2)}),
  'typed (DW-5: own draft per slot)': (
    const SlotTyped(_btc, 'bc1qx'),
    {
      3: _ready(const SlotEditing('bc1qx')),
      4: _ready(const SlotEditing('bc1qx')),
      5: _ready(const SlotEditing('bc1qx')),
      11: _ready(const SlotEditing('bc1qx'), lightning: _lnSaving),
    },
  ),
  'cancel': (
    const SlotCancelPressed(_btc),
    {
      4: _ready(const SlotShowing()),
      5: _ready(const SlotShowing()),
      11: _ready(const SlotShowing(), lightning: _lnSaving),
    },
  ),
  'save pressed': (
    const SlotSavePressed(_btc),
    {
      4: _ready(const SlotChecking('bc1qnew', 6), attempts: 6),
      5: _ready(
        const SlotEditing(
          '  ',
          problem: ExchangeDefaultWalletAddressEmptyFailure(),
        ),
      ),
    },
  ),
  'checked valid': (
    const SlotChecked(_btc, 5, WalletAddressValid('bc1qnorm')),
    {6: _ready(const SlotSaving('bc1qnew', 'bc1qnorm', 5))},
  ),
  'checked invalid': (
    const SlotChecked(_btc, 5, WalletAddressInvalid()),
    {
      6: _ready(
        const SlotEditing(
          'bc1qnew',
          problem: ExchangeDefaultWalletAddressInvalidFailure(_btc),
        ),
      ),
    },
  ),
  'check failed': (
    const SlotChecked(_btc, 5, WalletAddressCheckFailed()),
    {
      6: _ready(
        const SlotEditing(
          'bc1qnew',
          problem: ExchangeDefaultWalletSaveFailure(),
        ),
      ),
    },
  ),
  'checked, stale attempt': (
    const SlotChecked(_btc, 4, WalletAddressValid('bc1qnorm')),
    {},
  ),
  'save done': (
    SlotSaveAnswered(_btc, 5, _saveAnswer(const Ok(_newWallet))),
    {7: _ready(const SlotShowing(notice: SlotNoticeSaved()), saved: _withNew)},
  ),
  'save outcome unknown (DW-2)': (
    SlotSaveAnswered(
      _btc,
      5,
      _saveAnswer(const Err(ExchangeWriteOutcomeUnknownFailure('504'))),
    ),
    {7: _ready(const SlotVerifying(_saveIntent, 6), attempts: 6)},
  ),
  'save refused': (
    SlotSaveAnswered(
      _btc,
      5,
      _saveAnswer(
        const Err(
          ExchangeWriteRefusedFailure(ExchangeRefusal(httpStatus: 400)),
        ),
      ),
    ),
    {
      7: _ready(
        const SlotEditing(
          'bc1qnew',
          problem: ExchangeDefaultWalletSaveFailure(),
        ),
      ),
    },
  ),
  'save session rejected': (
    SlotSaveAnswered(
      _btc,
      5,
      _saveAnswer(
        const Err(
          ExchangeSessionRejectedFailure(ExchangeSessionRejection.server),
        ),
      ),
    ),
    {7: const WalletsSessionEnded()},
  ),
  'save session changed': (
    SlotSaveAnswered(
      _btc,
      5,
      _saveAnswer(
        const Err(
          ExchangeWriteNotSentFailure(ExchangeNotSentReason.sessionChanged),
        ),
      ),
    ),
    {7: const WalletsSessionEnded()},
  ),
  'save refused by the gate, busy': (
    const SlotSaveAnswered(
      _btc,
      5,
      GateRefused(WriteGateBusy(FinancialWriteKind.orderConfirm)),
    ),
    {
      7: _ready(
        const SlotEditing('bc1qnew', problem: ExchangeWriteBusyFailure()),
      ),
    },
  ),
  'save refused by the gate, unsettled': (
    SlotSaveAnswered(_btc, 5, GateRefused(WriteGateUnsettled(_entry))),
    {7: _ready(const SlotVerifying(_saveIntent, 6), attempts: 6)},
  ),
  'save answer, stale attempt': (
    SlotSaveAnswered(_btc, 4, _saveAnswer(const Ok(_newWallet))),
    {},
  ),
  'unset pressed (DW-4)': (
    const SlotUnsetPressed(_btc),
    {3: _ready(const SlotUnsetting(6), attempts: 6)},
  ),
  'unset done (DW-3)': (
    const SlotUnsetAnswered(_btc, 5, GateAdmitted(Ok(null))),
    {
      8: _ready(
        const SlotShowing(notice: SlotNoticeUnset()),
        saved: const DefaultWallets(),
      ),
    },
  ),
  'unset outcome unknown': (
    const SlotUnsetAnswered(
      _btc,
      5,
      GateAdmitted(Err(ExchangeWriteOutcomeUnknownFailure('x'))),
    ),
    {8: _ready(const SlotVerifying(SlotUnsetIntent(), 6), attempts: 6)},
  ),
  'unset refused': (
    const SlotUnsetAnswered(
      _btc,
      5,
      GateAdmitted(
        Err(ExchangeWriteRefusedFailure(ExchangeRefusal(httpStatus: 400))),
      ),
    ),
    {
      8: _ready(
        const SlotShowing(
          notice: SlotNoticeFailed(ExchangeDefaultWalletDeleteFailure()),
        ),
      ),
    },
  ),
  'verified applied': (
    const SlotVerified(_btc, 5, Ok(_withNew)),
    {9: _ready(const SlotShowing(notice: SlotNoticeSaved()), saved: _withNew)},
  ),
  'verified not applied': (
    const SlotVerified(_btc, 5, Ok(_saved)),
    {
      9: _ready(
        const SlotEditing(
          'bc1qnew',
          problem: ExchangeDefaultWalletSaveFailure(),
        ),
      ),
    },
  ),
  'verify read failed': (
    const SlotVerified(_btc, 5, _serverDown),
    {
      9: _ready(
        const SlotUnverified(
          _saveIntent,
          ReadProblemUnreachable(isNetwork: false),
        ),
      ),
    },
  ),
  'verify rejected': (
    const SlotVerified(_btc, 5, _rejected),
    {9: const WalletsSessionEnded()},
  ),
  'verify, stale attempt': (const SlotVerified(_btc, 4, Ok(_withNew)), {}),
  'check again': (
    const SlotVerifyRetryPressed(_btc),
    {10: _ready(const SlotVerifying(_saveIntent, 6), attempts: 6)},
  ),
};

void main() {
  group('every (state, event) pair', () {
    for (final MapEntry(key: name, value: (event, changes)) in _table.entries) {
      for (final (index, state) in _states.indexed) {
        test('$name from state $index', () {
          final next = state.next(event);
          if (changes[index] case final expected?) {
            expect(next.state, expected);
          } else {
            expect(identical(next.state, state), isTrue);
            expect(next.effects, isEmpty);
          }
        });
      }
    }
  });

  group('effects', () {
    test('start reads the wallets of the session', () {
      expect(
        defaultWalletsStart(_s),
        StepNext<DefaultWalletsState, DefaultWalletsEffect>(
          const WalletsLoading(_s, 1),
          const [FetchDefaultWallets(_s, 1)],
        ),
      );
      expect(defaultWalletsStart(null).state, const WalletsSessionEnded());
    });

    test('retry reads again with a new attempt', () {
      expect((_states[1]).next(const WalletsRetryPressed()).effects, const [
        FetchDefaultWallets(_s, 2),
      ]);
    });

    test('save checks the typed address first', () {
      expect((_states[4]).next(const SlotSavePressed(_btc)).effects, const [
        CheckWalletAddress(_btc, 6, 'bc1qnew'),
      ]);
    });

    test('a valid address is saved over the existing recipient (DW-2)', () {
      expect(
        (_states[6])
            .next(const SlotChecked(_btc, 5, WalletAddressValid('bc1qnorm')))
            .effects,
        const [
          SaveDefaultWallet(_s, _btc, 5, 'bc1qnorm', existingRecipientId: 'r1'),
        ],
      );
    });

    test('an unknown outcome re-reads, never saves again', () {
      expect(
        (_states[7])
            .next(
              SlotSaveAnswered(
                _btc,
                5,
                _saveAnswer(
                  const Err(ExchangeWriteOutcomeUnknownFailure('504')),
                ),
              ),
            )
            .effects,
        const [VerifyDefaultWallets(_s, _btc, 6)],
      );
    });

    test('unset names the saved recipient', () {
      expect((_states[3]).next(const SlotUnsetPressed(_btc)).effects, const [
        UnsetDefaultWallet(
          _s,
          _btc,
          6,
          recipientId: 'r1',
          address: 'bc1qsaved',
        ),
      ]);
    });
  });

  group('one mutation at a time across slots', () {
    test('another slot can not save or unset while one saves', () {
      final state = _ready(const SlotShowing(), lightning: _lnSaving);
      expect(
        identical(state.next(const SlotUnsetPressed(_btc)).state, state),
        isTrue,
      );
      final editing = _states[11];
      expect(
        identical(editing.next(const SlotSavePressed(_btc)).state, editing),
        isTrue,
      );
    });

    test('an unset verified as applied empties the slot', () {
      final verifying = _ready(const SlotVerifying(SlotUnsetIntent(), 5));
      expect(
        verifying.next(const SlotVerified(_btc, 5, Ok(DefaultWallets()))).state,
        _ready(
          const SlotShowing(notice: SlotNoticeUnset()),
          saved: const DefaultWallets(),
        ),
      );
      expect(
        verifying.next(const SlotVerified(_btc, 5, Ok(_saved))).state,
        _ready(
          const SlotShowing(
            notice: SlotNoticeFailed(ExchangeDefaultWalletDeleteFailure()),
          ),
        ),
      );
    });

    test('a slot without a saved recipient offers no unset', () {
      final state = _ready(const SlotShowing(), saved: const DefaultWallets());
      expect(
        identical(state.next(const SlotUnsetPressed(_btc)).state, state),
        isTrue,
      );
    });
  });

  test('every state and slot kind is reachable from the start', () {
    final seen = <String>{};
    final start = defaultWalletsStart(_s);
    final queue = <(DefaultWalletsState, List<DefaultWalletsEffect>)>[
      (start.state, start.effects),
    ];
    final visited = <DefaultWalletsState>{};
    while (queue.isNotEmpty && visited.length < 3000) {
      final (state, effects) = queue.removeAt(0);
      if (!visited.add(state)) continue;
      seen.add(_kind(state));
      for (final event in [
        ..._userEvents,
        for (final e in effects) ..._answers(e),
      ]) {
        final next = state.next(event);
        if (!identical(next.state, state)) {
          queue.add((next.state, next.effects));
        }
      }
    }
    expect(seen, {
      'WalletsLoading',
      'WalletsLoadFailed',
      'WalletsSessionEnded',
      'SlotShowing',
      'SlotEditing',
      'SlotChecking',
      'SlotSaving',
      'SlotUnsetting',
      'SlotVerifying',
      'SlotUnverified',
    });
  });
}

String _kind(DefaultWalletsState state) => switch (state) {
  WalletsReady(:final slots) => slots.bitcoin.runtimeType.toString(),
  _ => state.runtimeType.toString(),
};

const _userEvents = <DefaultWalletsEvent>[
  WalletsRetryPressed(),
  SlotTyped(_btc, 'bc1qnew'),
  SlotCancelPressed(_btc),
  SlotSavePressed(_btc),
  SlotUnsetPressed(_btc),
  SlotVerifyRetryPressed(_btc),
];

List<DefaultWalletsEvent> _answers(DefaultWalletsEffect effect) =>
    switch (effect) {
      FetchDefaultWallets(:final attempt) => [
        WalletsLoaded(attempt, const Ok(_saved)),
        WalletsLoaded(attempt, _netDown),
        WalletsLoaded(attempt, _rejected),
      ],
      CheckWalletAddress(:final network, :final attempt) => [
        SlotChecked(network, attempt, const WalletAddressValid('bc1qnorm')),
      ],
      SaveDefaultWallet(:final network, :final attempt) => [
        SlotSaveAnswered(network, attempt, _saveAnswer(const Ok(_newWallet))),
        SlotSaveAnswered(
          network,
          attempt,
          _saveAnswer(const Err(ExchangeWriteOutcomeUnknownFailure('504'))),
        ),
      ],
      UnsetDefaultWallet(:final network, :final attempt) => [
        SlotUnsetAnswered(network, attempt, const GateAdmitted(Ok(null))),
      ],
      VerifyDefaultWallets(:final network, :final attempt) => [
        SlotVerified(network, attempt, const Ok(_withNew)),
        SlotVerified(network, attempt, _serverDown),
      ],
    };
