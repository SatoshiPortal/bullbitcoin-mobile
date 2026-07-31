import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/tx_recipient.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_failure.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_plan.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../coins/wallet_utxo_fixture.dart';

const _alice = 'tb1qalice000000000000000000000000000000000';
const _bob = 'tb1qbob00000000000000000000000000000000000';

BigInt _sats(int value) => BigInt.from(value);

/// Unwraps an expected [Ok], failing the test with the failure otherwise.
SweepPlan _expectOk(Result<SweepPlan, SweepFailure> result) {
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw TestFailure(
      'expected Ok, got ${failure.runtimeType}',
    ),
  };
}

/// Unwraps an expected [Err].
SweepFailure _expectErr(Result<SweepPlan, SweepFailure> result) {
  return switch (result) {
    Ok() => throw TestFailure('expected Err, got Ok'),
    Err(:final failure) => failure,
  };
}

void main() {
  final inputs = <WalletUtxo>[
    walletUtxoFixture(sats: 60000, txId: 'a', vout: 0),
    walletUtxoFixture(sats: 40000, txId: 'b', vout: 1),
  ];

  group('SweepPlan.validate — rejections', () {
    test('no inputs', () {
      final failure = _expectErr(
        SweepPlan.validate(
          inputs: const [],
          allocations: const [SweepAllocation(address: _alice)],
        ),
      );
      expect(failure, isA<SweepNoInputsFailure>());
    });

    test('no recipients', () {
      final failure = _expectErr(
        SweepPlan.validate(inputs: inputs, allocations: const []),
      );
      expect(failure, isA<SweepNoRecipientsFailure>());
    });

    test('a blank address', () {
      final failure = _expectErr(
        SweepPlan.validate(
          inputs: inputs,
          allocations: const [SweepAllocation(address: '   ')],
        ),
      );
      expect(failure, isA<SweepMissingAddressFailure>());
    });

    test('the same address twice', () {
      final failure = _expectErr(
        SweepPlan.validate(
          inputs: inputs,
          allocations: [
            SweepAllocation(address: _alice, amountSat: _sats(1000)),
            SweepAllocation(address: _alice, amountSat: _sats(2000)),
          ],
        ),
      );
      expect(failure, isA<SweepDuplicateAddressFailure>());
      expect((failure as SweepDuplicateAddressFailure).address, _alice);
    });

    test('duplicate detection ignores surrounding whitespace', () {
      final failure = _expectErr(
        SweepPlan.validate(
          inputs: inputs,
          allocations: [
            SweepAllocation(address: _alice, amountSat: _sats(1000)),
            SweepAllocation(address: '  $_alice  ', amountSat: _sats(2000)),
          ],
        ),
      );
      expect(failure, isA<SweepDuplicateAddressFailure>());
    });

    test('two rows claiming the remainder', () {
      final failure = _expectErr(
        SweepPlan.validate(
          inputs: inputs,
          allocations: const [
            SweepAllocation(address: _alice, takesRemainder: true),
            SweepAllocation(address: _bob, takesRemainder: true),
          ],
        ),
      );
      expect(failure, isA<SweepMultipleRemainderFailure>());
    });

    test('a pinned row with no amount', () {
      final failure = _expectErr(
        SweepPlan.validate(
          inputs: inputs,
          allocations: const [SweepAllocation(address: _alice)],
        ),
      );
      expect(failure, isA<SweepMissingAmountFailure>());
    });

    test('an amount below the dust floor of its address type', () {
      // _alice is bech32 P2WPKH → 294, not the P2PKH 546.
      final failure = _expectErr(
        SweepPlan.validate(
          inputs: inputs,
          allocations: [
            SweepAllocation(address: _alice, amountSat: _sats(293)),
          ],
        ),
      );
      expect(failure, isA<SweepAmountBelowDustFailure>());
      expect((failure as SweepAmountBelowDustFailure).minimumSat, _sats(294));
    });

    test('300 sats to a bech32 recipient is accepted, not called dust', () {
      // Regression: a blanket 546 floor refused this, though the network relays
      // a 294-sat P2WPKH output perfectly well.
      final plan = _expectOk(
        SweepPlan.validate(
          inputs: inputs,
          allocations: [
            SweepAllocation(address: _alice, amountSat: _sats(300)),
          ],
        ),
      );
      expect(plan.allocatedSat, _sats(300));
    });

    test('the same 300 sats to a legacy P2PKH recipient is dust', () {
      final failure = _expectErr(
        SweepPlan.validate(
          inputs: inputs,
          allocations: [
            SweepAllocation(
              address: 'mipcBbFg9gMiCh81Kj8tqqdgoZub1ZJRfn',
              amountSat: _sats(300),
            ),
          ],
        ),
      );
      expect((failure as SweepAmountBelowDustFailure).minimumSat, _sats(546));
    });

    test('allocating more than the coins hold reports the excess', () {
      final failure = _expectErr(
        SweepPlan.validate(
          inputs: inputs,
          allocations: [
            SweepAllocation(address: _alice, amountSat: _sats(100_001)),
          ],
        ),
      );
      expect(failure, isA<SweepAllocationExceedsBalanceFailure>());
      expect(
        (failure as SweepAllocationExceedsBalanceFailure).overspentSat,
        _sats(1),
      );
    });

    test('allocating every satoshi leaves nothing for the fee', () {
      final failure = _expectErr(
        SweepPlan.validate(
          inputs: inputs,
          allocations: [
            SweepAllocation(address: _alice, amountSat: _sats(100_000)),
          ],
        ),
      );
      expect(failure, isA<SweepNoRoomForFeeFailure>());
    });
  });

  group('SweepPlan.validate — acceptance', () {
    test('a single pinned recipient, remainder left as change', () {
      final plan = _expectOk(
        SweepPlan.validate(
          inputs: inputs,
          allocations: [
            SweepAllocation(address: _alice, amountSat: _sats(30000)),
          ],
        ),
      );

      expect(plan.recipients, [
        FixedTxRecipient(address: _alice, amountSat: _sats(30000)),
      ]);
      expect(plan.totalInputSat, _sats(100_000));
      expect(plan.allocatedSat, _sats(30000));
      expect(plan.unallocatedSat, _sats(70000));
      expect(plan.hasRemainderRecipient, isFalse);
    });

    test('a remainder row becomes a drain recipient', () {
      final plan = _expectOk(
        SweepPlan.validate(
          inputs: inputs,
          allocations: [
            SweepAllocation(address: _alice, amountSat: _sats(30000)),
            const SweepAllocation(address: _bob, takesRemainder: true),
          ],
        ),
      );

      expect(plan.recipients.first, isA<FixedTxRecipient>());
      expect(plan.recipients.last, DrainTxRecipient(address: _bob));
      expect(plan.hasRemainderRecipient, isTrue);
    });

    test('addresses are trimmed on the way in', () {
      final plan = _expectOk(
        SweepPlan.validate(
          inputs: inputs,
          allocations: [
            SweepAllocation(address: '  $_alice\n', amountSat: _sats(30000)),
          ],
        ),
      );

      expect(plan.recipients.single.address, _alice);
    });

    test('outpoints mirror the inputs', () {
      final plan = _expectOk(
        SweepPlan.validate(
          inputs: inputs,
          allocations: [
            SweepAllocation(address: _alice, amountSat: _sats(30000)),
          ],
        ),
      );

      expect(plan.outpoints, [(txId: 'a', vout: 0), (txId: 'b', vout: 1)]);
    });

    test('the returned lists cannot be mutated', () {
      final plan = _expectOk(
        SweepPlan.validate(
          inputs: inputs,
          allocations: [
            SweepAllocation(address: _alice, amountSat: _sats(30000)),
          ],
        ),
      );

      expect(
        () => plan.recipients.add(DrainTxRecipient(address: _bob)),
        throwsUnsupportedError,
      );
      expect(() => plan.inputs.clear(), throwsUnsupportedError);
    });
  });

  group('minimumOutputSatFor', () {
    test('prices each script type on its own dust threshold', () {
      expect(SweepPlan.minimumOutputSatFor(_alice), _sats(294)); // tb1q P2WPKH
      expect(SweepPlan.minimumOutputSatFor(_bob), _sats(294));
      expect(
        // 62-char bech32 → 32-byte witness program (P2WSH).
        SweepPlan.minimumOutputSatFor(
          'tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3q0sl5k7',
        ),
        _sats(330),
      );
      expect(
        SweepPlan.minimumOutputSatFor(
          'tb1pqqqqp399et2xygdj5xreqhjjvcmzhxw4aywxecjdzew6hylgvsesf3hn0c',
        ),
        _sats(330),
      ); // taproot
      expect(
        SweepPlan.minimumOutputSatFor('2N2JD6wb56AfK4tfmM6PwdVmoYk2dCKf4Br'),
        _sats(540),
      ); // P2SH
      expect(
        SweepPlan.minimumOutputSatFor('mipcBbFg9gMiCh81Kj8tqqdgoZub1ZJRfn'),
        _sats(546),
      ); // P2PKH
    });

    test('falls back to the highest threshold when unrecognised', () {
      expect(SweepPlan.minimumOutputSatFor('nonsense'), _sats(546));
    });

    test('two 450-sat bech32 outputs from a 1188-sat coin are valid', () {
      // Mainnet tx fd060b88…46dc: one 1188-sat P2WPKH input split into two
      // 450-sat P2WPKH outputs with no change. A blanket 546 floor refused both;
      // the network relayed them. This is the regression that case guards.
      final coin = [walletUtxoFixture(sats: 1188, txId: 'a29bac', vout: 1)];
      final plan = _expectOk(
        SweepPlan.validate(
          inputs: coin,
          allocations: [
            SweepAllocation(address: _alice, amountSat: _sats(450)),
            const SweepAllocation(address: _bob, takesRemainder: true),
          ],
        ),
      );

      expect(plan.allocatedSat, _sats(450));
      // 1188 − 450 − 288 of fee left 450 for the drained recipient.
      expect(plan.remainderSat(_sats(288)), _sats(450));
      expect(plan.changeSat(_sats(288)), isNull);
    });

    test('is case- and whitespace-insensitive', () {
      expect(
        SweepPlan.minimumOutputSatFor('  ${_alice.toUpperCase()} '),
        _sats(294),
      );
    });
  });

  group('remainder and change arithmetic', () {
    test('change is the leftover net of the fee when no row takes it', () {
      final plan = _expectOk(
        SweepPlan.validate(
          inputs: inputs,
          allocations: [
            SweepAllocation(address: _alice, amountSat: _sats(30000)),
          ],
        ),
      );

      expect(plan.changeSat(_sats(500)), _sats(69500));
      expect(plan.remainderSat(_sats(500)), isNull);
    });

    test('the drain recipient takes the leftover net of the fee', () {
      final plan = _expectOk(
        SweepPlan.validate(
          inputs: inputs,
          allocations: [
            SweepAllocation(address: _alice, amountSat: _sats(30000)),
            const SweepAllocation(address: _bob, takesRemainder: true),
          ],
        ),
      );

      expect(plan.remainderSat(_sats(500)), _sats(69500));
      expect(plan.changeSat(_sats(500)), isNull);
    });
  });
}
