import 'dart:typed_data';

import 'package:bull_exchange/src/payin/spend_options.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:fees/fees.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync/sync.dart' show BitcoinCoin, Keychain;

const _fees = FeeOptions(
  fastest: RelativeFee(2500),
  economic: RelativeFee(1250),
  slow: RelativeFee(500),
  minRelay: RelativeFee(25),
);
const _target = SpendPreviewTarget('bc1qdeposit', 20000);
const _custom = RelativeFee(1000);
const _slot = BitcoinFeePreviewSlot(feeSat: 350, txSize: 141);

final _coin = BitcoinCoin(
  outpoint: (txId: 'c1', vout: 0),
  amountSat: BigInt.from(50000),
  scriptPubkey: Uint8List(0),
  address: 'bc1qcoin',
  keychain: Keychain.external,
  confirmations: 3,
);
final _frozen = BitcoinCoin(
  outpoint: (txId: 'c2', vout: 1),
  amountSat: BigInt.from(1000),
  scriptPubkey: Uint8List(0),
  address: 'bc1qfrozen',
  keychain: Keychain.internal,
  confirmations: 3,
  frozen: true,
);

const _ready = SpendOptionsReady(walletId: 'w1', fees: _fees);
const _targeted = SpendOptionsReady(
  walletId: 'w1',
  fees: _fees,
  target: _target,
);
const _armed = SpendOptionsReady(
  walletId: 'w1',
  fees: _fees,
  target: _target,
  selection: FeeSelection.custom,
  customFee: _custom,
  arm: SpendCustomArm(FeeSelection.fastest, null),
);
const _coinsLoading = SpendOptionsReady(
  walletId: 'w1',
  fees: _fees,
  coins: SpendCoinsLoading(),
);

final _states = <String, SpendOptionsState>{
  'none': const SpendOptionsNone(),
  'fixed': const SpendOptionsFixed(PayinSpendOptions.liquid),
  'loading': const SpendFeesLoading('w1', 1),
  'unavailable': const SpendFeesUnavailable('w1', 1),
  'ready': _ready,
  'targeted': _targeted,
  'armed': _armed,
  'coinsLoading': _coinsLoading,
};

final _events = <String, SpendOptionsEvent>{
  'feesLoaded': const SpendFeesLoaded(1, _fees),
  'feesFailed': const SpendFeesFailed(1),
  'retry': const SpendRetryPressed(),
  'target': const SpendTargetSet(_target),
  'presets': const SpendPresetPreviewsRequested(),
  'customPreview': const SpendCustomPreviewRequested(_custom),
  'presetsPreviewed': const SpendPresetsPreviewed(0, {
    FeeSelection.fastest: _slot,
  }),
  'customPreviewed': const SpendCustomPreviewed(0, _custom, _slot),
  'pick': const SpendFeePicked(FeeSelection.economic),
  'arm': const SpendCustomFeeArmed(_custom),
  'disarm': const SpendCustomFeeDisarmed(),
  'finalize': const SpendCustomFeeFinalized(),
  'rbf': const SpendRbfChanged(enabled: false),
  'payjoin': const SpendPayjoinChanged(enabled: false),
  'coinsRequested': const SpendCoinsRequested(),
  'coinsRead': SpendCoinsRead([_coin]),
  'coinsPicked': SpendCoinsPicked([_coin]),
};

/// Every (state, event) pair that is not a stay, and the state it leads to.
const _moves = <(String, String), Type>{
  ('loading', 'feesLoaded'): SpendOptionsReady,
  ('loading', 'feesFailed'): SpendFeesUnavailable,
  ('unavailable', 'retry'): SpendFeesLoading,
  ('ready', 'target'): SpendOptionsReady,
  ('ready', 'presetsPreviewed'): SpendOptionsReady,
  ('ready', 'pick'): SpendOptionsReady,
  ('ready', 'arm'): SpendOptionsReady,
  ('ready', 'rbf'): SpendOptionsReady,
  ('ready', 'payjoin'): SpendOptionsReady,
  ('ready', 'coinsRequested'): SpendOptionsReady,
  ('ready', 'coinsPicked'): SpendOptionsReady,
  ('targeted', 'presets'): SpendOptionsReady,
  ('targeted', 'customPreview'): SpendOptionsReady,
  ('targeted', 'presetsPreviewed'): SpendOptionsReady,
  ('targeted', 'pick'): SpendOptionsReady,
  ('targeted', 'arm'): SpendOptionsReady,
  ('targeted', 'rbf'): SpendOptionsReady,
  ('targeted', 'payjoin'): SpendOptionsReady,
  ('targeted', 'coinsRequested'): SpendOptionsReady,
  ('targeted', 'coinsPicked'): SpendOptionsReady,
  ('armed', 'presets'): SpendOptionsReady,
  ('armed', 'customPreview'): SpendOptionsReady,
  ('armed', 'presetsPreviewed'): SpendOptionsReady,
  ('armed', 'customPreviewed'): SpendOptionsReady,
  ('armed', 'pick'): SpendOptionsReady,
  ('armed', 'disarm'): SpendOptionsReady,
  ('armed', 'finalize'): SpendOptionsReady,
  ('armed', 'rbf'): SpendOptionsReady,
  ('armed', 'payjoin'): SpendOptionsReady,
  ('armed', 'coinsRequested'): SpendOptionsReady,
  ('armed', 'coinsPicked'): SpendOptionsReady,
  ('coinsLoading', 'target'): SpendOptionsReady,
  ('coinsLoading', 'presetsPreviewed'): SpendOptionsReady,
  ('coinsLoading', 'pick'): SpendOptionsReady,
  ('coinsLoading', 'arm'): SpendOptionsReady,
  ('coinsLoading', 'rbf'): SpendOptionsReady,
  ('coinsLoading', 'payjoin'): SpendOptionsReady,
  ('coinsLoading', 'coinsRead'): SpendOptionsReady,
  ('coinsLoading', 'coinsPicked'): SpendOptionsReady,
};

SpendOptionsState _apply(SpendOptionsState state, SpendOptionsEvent event) =>
    state.next(event).state;

void main() {
  group('every (state, event) pair', () {
    for (final MapEntry(key: stateName, value: state) in _states.entries) {
      for (final MapEntry(key: eventName, value: event) in _events.entries) {
        final expected = _moves[(stateName, eventName)];
        test('$stateName + $eventName', () {
          final next = state.next(event);
          if (expected == null) {
            expect(next.state, state, reason: '$next');
            expect(next.effects, isEmpty);
          } else {
            expect(next.state.runtimeType, expected);
            expect(next.state, isNot(state));
          }
        });
      }
    }
  });

  test('every state is reachable from the starts', () {
    final reached = <Type>{};
    var frontier = <SpendOptionsState>[
      for (final source in const [
        PayinFromAppWallet('w1', BtcNetwork.bitcoin),
        PayinFromAppWallet('w1', BtcNetwork.liquid),
        PayinFromExternal(BtcNetwork.bitcoin),
      ])
        spendOptionsStart(source).state,
    ];
    final seen = <SpendOptionsState>{...frontier};
    while (frontier.isNotEmpty) {
      final next = <SpendOptionsState>[];
      for (final state in frontier) {
        reached.add(state.runtimeType);
        for (final event in _events.values) {
          final target = _apply(state, event);
          if (seen.add(target)) next.add(target);
        }
      }
      frontier = next.take(200).toList();
    }
    expect(reached, {
      SpendOptionsNone,
      SpendOptionsFixed,
      SpendFeesLoading,
      SpendFeesUnavailable,
      SpendOptionsReady,
    });
  });

  group('start', () {
    test('an on-chain app wallet reads the fee estimates', () {
      expect(
        spendOptionsStart(const PayinFromAppWallet('w1', BtcNetwork.bitcoin)),
        const SpendOptionsNext(SpendFeesLoading('w1', 1), [SpendLoadFees(1)]),
      );
    });

    test('Liquid pays the network minimum; external builds nothing', () {
      expect(
        spendOptionsStart(const PayinFromAppWallet('w1', BtcNetwork.liquid))
            .state,
        const SpendOptionsFixed(PayinSpendOptions.liquid),
      );
      expect(
        spendOptionsStart(const PayinFromExternal(BtcNetwork.lightning)).state,
        const SpendOptionsNone(),
      );
    });
  });

  group('fee estimates', () {
    test('a failure is its own state, never a default fee', () {
      final failed = _apply(
        const SpendFeesLoading('w1', 1),
        const SpendFeesFailed(1),
      );
      expect(spendOptionsChosen(failed), isA<SpendNotChosen>());
      final retried = failed.next(const SpendRetryPressed());
      expect(retried.state, const SpendFeesLoading('w1', 2));
      expect(retried.effects, [const SpendLoadFees(2)]);
    });

    test('an answer for an older attempt is a stay', () {
      const loading = SpendFeesLoading('w1', 2);
      expect(_apply(loading, const SpendFeesLoaded(1, _fees)), loading);
      expect(_apply(loading, const SpendFeesFailed(1)), loading);
    });

    test('while loading, Confirm has nothing to build with', () {
      expect(
        spendOptionsChosen(const SpendFeesLoading('w1', 1)),
        isA<SpendNotChosen>(),
      );
    });
  });

  group('chosen options', () {
    test('the defaults: fastest, RBF on, the wallet picks, payjoin on', () {
      final chosen = spendOptionsChosen(_ready) as SpendChosen;
      expect(
        chosen.options,
        const PayinSpendOptions(
          fee: PayinFeeRate(2500),
          replaceByFee: true,
          coins: {},
          payjoin: true,
        ),
      );
    });

    test('every option the user changed goes into the payin', () {
      var state = _apply(_targeted, const SpendFeePicked(FeeSelection.slow));
      state = _apply(state, const SpendRbfChanged(enabled: false));
      state = _apply(state, const SpendPayjoinChanged(enabled: false));
      state = _apply(state, SpendCoinsPicked([_coin]));
      expect(
        (spendOptionsChosen(state) as SpendChosen).options,
        const PayinSpendOptions(
          fee: PayinFeeRate(500),
          replaceByFee: false,
          coins: {(txId: 'c1', vout: 0)},
          payjoin: false,
        ),
      );
    });

    test('an absolute custom fee is kept as sats', () {
      var state = _apply(
        _targeted,
        const SpendCustomFeeArmed(AbsoluteFee(800)),
      );
      state = _apply(state, const SpendCustomFeeFinalized());
      expect(
        (spendOptionsChosen(state) as SpendChosen).options?.fee,
        const PayinFeeAbsolute(800),
      );
    });

    test('external has no options; Liquid has its fixed ones', () {
      expect(
        (spendOptionsChosen(const SpendOptionsNone()) as SpendChosen).options,
        isNull,
      );
      expect(
        (spendOptionsChosen(
          const SpendOptionsFixed(PayinSpendOptions.liquid),
        ) as SpendChosen).options,
        PayinSpendOptions.liquid,
      );
    });
  });

  group('custom fee', () {
    test('a value under the relay floor rolls back on close', () {
      var state = _apply(_targeted, const SpendFeePicked(FeeSelection.slow));
      state = _apply(state, const SpendCustomFeeArmed(RelativeFee(10)));
      expect((state as SpendOptionsReady).selection, FeeSelection.custom);
      state = _apply(state, const SpendCustomFeeFinalized());
      expect((state as SpendOptionsReady).selection, FeeSelection.slow);
      expect(state.arm, isNull);
    });

    test('a valid value is kept and priced', () {
      final next = _armed.next(const SpendCustomFeeFinalized());
      final state = next.state as SpendOptionsReady;
      expect(state.selection, FeeSelection.custom);
      expect(state.arm, isNull);
      expect(
        next.effects,
        contains(
          const SpendPreviewCustom(
            0,
            _custom,
            SpendPreviewShape('w1', _target, true, {}),
          ),
        ),
      );
    });

    test('a preset can only pick custom once it has a value', () {
      expect(_apply(_ready, const SpendFeePicked(FeeSelection.custom)), _ready);
    });
  });

  group('previews', () {
    test('a new quote drops the previews and prices the presets again', () {
      final next = _ready.next(const SpendTargetSet(_target));
      final state = next.state as SpendOptionsReady;
      expect(state.epoch, 1);
      expect(state.previews.presetsLoading, isTrue);
      expect(next.effects, [
        const SpendPreviewPresets(
          1,
          _fees,
          SpendPreviewShape('w1', _target, true, {}),
        ),
      ]);
    });

    test('a preview of an older epoch is a stay', () {
      final reshaped = _apply(_targeted, const SpendRbfChanged(enabled: false));
      expect(
        _apply(
          reshaped,
          const SpendPresetsPreviewed(0, {FeeSelection.fastest: _slot}),
        ),
        reshaped,
      );
    });

    test('RBF and the coins change the shape priced', () {
      final next = _targeted.next(SpendCoinsPicked([_coin]));
      expect(next.effects.single, isA<SpendPreviewPresets>());
      expect((next.effects.single as SpendPreviewPresets).shape.coins, {
        (txId: 'c1', vout: 0),
      });
    });
  });

  group('coins', () {
    test(
      'opening the selection reads the coins once; frozen ones are hidden',
      () {
        final next = _ready.next(const SpendCoinsRequested());
        expect(next.effects, [const SpendLoadCoins('w1')]);
        final loaded = _apply(next.state, SpendCoinsRead([_coin, _frozen]));
        expect((loaded as SpendOptionsReady).coins, SpendCoinsLoaded([_coin]));
        expect(_apply(loaded, const SpendCoinsRequested()), loaded);
      },
    );

    test('a failed read is its own state and can be asked again', () {
      final failed = _apply(_coinsLoading, const SpendCoinsRead(null));
      expect(
        (failed as SpendOptionsReady).coins,
        const SpendCoinsUnavailable(),
      );
      expect(failed.next(const SpendCoinsRequested()).effects, [
        const SpendLoadCoins('w1'),
      ]);
    });
  });
}
