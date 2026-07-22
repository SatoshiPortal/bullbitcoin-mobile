import 'dart:typed_data';

import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/features/labels/label.dart';
import 'package:bb_mobile/features/send/domain/octojoin.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../coins/wallet_utxo_fixture.dart';

WalletUtxo _utxo({required int sats, required bool isSwapped, int vout = 0}) {
  return walletUtxoFixture(
    sats: sats,
    vout: vout,
    labels: isSwapped ? ['octojoin'] : [],
  );
}

Matcher _throwsIssue(OctojoinIssue issue) => throwsA(
  isA<OctojoinException>().having((e) => e.issue, 'issue', issue),
);

int Function(int, int) _feeAtRate(double satPerVbyte) =>
    (numInputs, numOutputs) => Octojoin.estimateFee(
      numInputs: numInputs,
      numOutputs: numOutputs,
      satPerVbyte: satPerVbyte,
    );

void main() {
  group('Octojoin protocol logic', () {
    test('decomposeAmount chunks into standard denominations', () {
      final denominations = Octojoin.decomposeAmount(300000);
      expect(denominations.length, 2);
      expect(denominations, contains(200000));
      expect(denominations, contains(100000));
    });

    test('decomposeAmount keeps a non-dust remainder as its own output', () {
      expect(Octojoin.decomposeAmount(101000), [100000, 1000]);
    });

    test(
      'decomposeAmount folds a sub-dust remainder into the last output '
      'instead of losing it to fees',
      () {
        expect(Octojoin.decomposeAmount(100500), [100500]);
        expect(Octojoin.decomposeAmount(100500).fold(0, (s, v) => s + v),
            100500);
      },
    );

    test(
      'decomposeAmount conserves value for a sub-dust total '
      '(the 501-546 sat window)',
      () {
        for (final amount in [501, 520, 546]) {
          expect(Octojoin.decomposeAmount(amount), isEmpty);
        }
        expect(Octojoin.decomposeAmount(547), [547]);
      },
    );

    test('plan rejects a sub-dust payment instead of donating it to fees', () {
      final utxos = [
        _utxo(sats: 100000, isSwapped: true),
        _utxo(sats: 100000, isSwapped: true, vout: 1),
        _utxo(sats: 100000, isSwapped: false, vout: 2),
      ];
      expect(
        () => Octojoin.plan(
          utxos: utxos,
          paymentSat: 520,
          addresses: ['a', 'b'],
          numInputs: 3,
          feeForShape: _feeAtRate(1),
        ),
        _throwsIssue(OctojoinIssue.amountBelowDust),
      );
    });

    test('isOctojoinLabel matches case-insensitively and within longer notes',
        () {
      expect(Octojoin.isOctojoinLabel('Octojoin 1'), true);
      expect(Octojoin.isOctojoinLabel('octojoin 2'), true);
      expect(Octojoin.isOctojoinLabel('my OCTOJOIN swap'), true);
      expect(Octojoin.isOctojoinLabel('Normal TX'), false);
      expect(Octojoin.isOctojoinLabel(''), false);
      expect(Octojoin.isOctojoinLabel(null), false);
    });

    test('isSwappedUtxo counts utxo, transaction and address labels', () {
      expect(Octojoin.isSwappedUtxo(_utxo(sats: 1000, isSwapped: true)), true);
      expect(Octojoin.isSwappedUtxo(_utxo(sats: 1000, isSwapped: false)), false);

      final txLabeled = WalletUtxo.bitcoin(
        walletId: 'w',
        txId: 'a' * 64,
        vout: 0,
        scriptPubkey: Uint8List(0),
        amountSat: BigInt.from(1000),
        address: 'bc1qtest',
        txLabels: [
          Label.tx(id: 0, transactionId: 'a' * 64, label: 'Octojoin receive'),
        ],
      );
      expect(Octojoin.isSwappedUtxo(txLabeled), true);

      final addressLabeled = WalletUtxo.bitcoin(
        walletId: 'w',
        txId: 'b' * 64,
        vout: 0,
        scriptPubkey: Uint8List(0),
        amountSat: BigInt.from(1000),
        address: 'bc1qtest2',
        addressLabels: [
          Label.addr(id: 0, address: 'bc1qtest2', label: 'octojoin'),
        ],
      );
      expect(Octojoin.isSwappedUtxo(addressLabeled), true);
    });

    test('selectUtxos isolates octojoin-tagged coins from the rest', () {
      final utxos = [
        _utxo(sats: 150000, isSwapped: true),
        _utxo(sats: 150000, isSwapped: true, vout: 1),
        _utxo(sats: 50000, isSwapped: false, vout: 2),
      ];

      final selection = Octojoin.selectUtxos(
        utxos: utxos,
        numInputs: 3,
        targetSat: 300000,
      );

      expect(selection.swapped.length, 2);
      expect(selection.all.length, 3);
      expect(selection.totalSat, 350000);
    });

    test(
      'selectUtxos uses exactly one non-octojoin sender coin and caps inputs '
      'at numInputs',
      () {
        final utxos = [
          _utxo(sats: 150000, isSwapped: true),
          _utxo(sats: 150000, isSwapped: true, vout: 1),
          _utxo(sats: 90000, isSwapped: false, vout: 2),
          _utxo(sats: 90000, isSwapped: false, vout: 3),
          _utxo(sats: 90000, isSwapped: false, vout: 4),
        ];
        final selection = Octojoin.selectUtxos(
          utxos: utxos,
          numInputs: 3,
          targetSat: 320000,
        );
        expect(selection.all.length, 3);
        expect(Octojoin.isSwappedUtxo(selection.sender), false);
        expect(selection.swapped.every(Octojoin.isSwappedUtxo), true);
      },
    );

    test(
      'selectUtxos picks the smallest single sender coin that covers the '
      'target',
      () {
        final utxos = [
          _utxo(sats: 100000, isSwapped: true),
          _utxo(sats: 100000, isSwapped: true, vout: 1),
          _utxo(sats: 50000, isSwapped: false, vout: 2),
          _utxo(sats: 130000, isSwapped: false, vout: 3),
          _utxo(sats: 900000, isSwapped: false, vout: 4),
        ];
        final selection = Octojoin.selectUtxos(
          utxos: utxos,
          numInputs: 3,
          targetSat: 320000,
        );
        expect(selection.sender.amountSat.toInt(), 130000);
        expect(selection.totalSat, 330000);
      },
    );

    test(
      'selectUtxos throws when no single sender coin can cover the target '
      '(no hoarding)',
      () {
        final utxos = [
          _utxo(sats: 100000, isSwapped: true),
          _utxo(sats: 100000, isSwapped: true, vout: 1),
          _utxo(sats: 60000, isSwapped: false, vout: 2),
          _utxo(sats: 60000, isSwapped: false, vout: 3),
        ];
        expect(
          () => Octojoin.selectUtxos(
            utxos: utxos,
            numInputs: 3,
            targetSat: 300000,
          ),
          _throwsIssue(OctojoinIssue.insufficientFunds),
        );
      },
    );

    test(
      'selectUtxos avoids the unnecessary input heuristic '
      '(change < smallest input)',
      () {
        final utxos = [
          _utxo(sats: 110000, isSwapped: true),
          _utxo(sats: 120000, isSwapped: true, vout: 1),
          _utxo(sats: 500000, isSwapped: true, vout: 2),
          _utxo(sats: 130000, isSwapped: false, vout: 3),
          _utxo(sats: 600000, isSwapped: false, vout: 4),
        ];
        final selection = Octojoin.selectUtxos(
          utxos: utxos,
          numInputs: 3,
          targetSat: 300000,
        );
        expect(selection.all.length, 3);
        final change = selection.totalSat - 300000;
        final minInput = selection.all
            .map((u) => u.amountSat.toInt())
            .reduce((a, b) => a < b ? a : b);
        expect(change, greaterThanOrEqualTo(0));
        expect(change, lessThan(minInput));
      },
    );

    test(
      'selectUtxos prefers a UIH-clean selection over a smaller-change one '
      'with an unnecessary input',
      () {
        final utxos = [
          _utxo(sats: 5000, isSwapped: true),
          _utxo(sats: 110000, isSwapped: true, vout: 1),
          _utxo(sats: 110000, isSwapped: true, vout: 2),
          _utxo(sats: 152000, isSwapped: true, vout: 3),
          _utxo(sats: 110000, isSwapped: false, vout: 4),
          _utxo(sats: 153000, isSwapped: false, vout: 5),
        ];
        final selection = Octojoin.selectUtxos(
          utxos: utxos,
          numInputs: 3,
          targetSat: 300000,
        );
        final change = selection.totalSat - 300000;
        final minInput = selection.all
            .map((u) => u.amountSat.toInt())
            .reduce((a, b) => a < b ? a : b);
        expect(change, lessThan(minInput));
        expect(selection.totalSat, 330000);
      },
    );

    test('selectUtxos throws when not enough octojoin coins', () {
      final utxos = [
        _utxo(sats: 150000, isSwapped: true),
        _utxo(sats: 50000, isSwapped: false, vout: 1),
      ];
      expect(
        () =>
            Octojoin.selectUtxos(utxos: utxos, numInputs: 3, targetSat: 100000),
        _throwsIssue(OctojoinIssue.notEnoughSwappedCoins),
      );
    });

    test('selectUtxos throws when no normal coin is available', () {
      final utxos = [
        _utxo(sats: 150000, isSwapped: true),
        _utxo(sats: 150000, isSwapped: true, vout: 1),
      ];
      expect(
        () =>
            Octojoin.selectUtxos(utxos: utxos, numInputs: 3, targetSat: 100000),
        _throwsIssue(OctojoinIssue.noSenderCoin),
      );
    });

    test('selectUtxos throws on insufficient total funds', () {
      final utxos = [
        _utxo(sats: 10000, isSwapped: true),
        _utxo(sats: 10000, isSwapped: true, vout: 1),
        _utxo(sats: 10000, isSwapped: false, vout: 2),
      ];
      expect(
        () => Octojoin.selectUtxos(
          utxos: utxos,
          numInputs: 3,
          targetSat: 1000000,
        ),
        _throwsIssue(OctojoinIssue.insufficientFunds),
      );
    });

    test('distributeOutputs maps denominations across addresses round-robin',
        () {
      final outputs = Octojoin.distributeOutputs(
        [200000, 100000, 1000],
        ['addr1', 'addr2'],
      );
      expect(outputs['addr1'], 201000);
      expect(outputs['addr2'], 100000);
    });

    test('estimateFee scales with size and fee rate', () {
      expect(
        Octojoin.estimateFee(numInputs: 3, numOutputs: 2, satPerVbyte: 1),
        11 + 3 * 68 + 2 * 34,
      );
      expect(
        Octojoin.estimateFee(numInputs: 3, numOutputs: 2, satPerVbyte: 2),
        (11 + 3 * 68 + 2 * 34) * 2,
      );
    });

    test('inputVbytesForScriptType matches the script type', () {
      expect(Octojoin.inputVbytesForScriptType(ScriptType.bip84), 68);
      expect(Octojoin.inputVbytesForScriptType(ScriptType.bip49), 91);
      expect(Octojoin.inputVbytesForScriptType(ScriptType.bip44), 148);
    });
  });

  group('Octojoin planning', () {
    final utxos = [
      _utxo(sats: 100000, isSwapped: true),
      _utxo(sats: 100000, isSwapped: true, vout: 1),
      _utxo(sats: 800000, isSwapped: false, vout: 2),
    ];

    test(
      'produces one payment output per address and selects the forced inputs',
      () {
        final plan = Octojoin.plan(
          utxos: utxos,
          paymentSat: 300000,
          addresses: ['addrA', 'addrB'],
          numInputs: 3,
          feeForShape: _feeAtRate(2),
        );

        expect(plan.targets.length, 2);
        expect(plan.inputs.length, 3);
        expect(plan.targets.fold(0, (s, t) => s + t.amountSat), 300000);
        expect(plan.totalInputSat, 1000000);
        expect(plan.targets[0].amountSat, 200000);
        expect(plan.targets[1].amountSat, 100000);
      },
    );

    test('requires at least two destination addresses', () {
      expect(
        () => Octojoin.plan(
          utxos: utxos,
          paymentSat: 300000,
          addresses: ['addrA'],
          numInputs: 3,
          feeForShape: _feeAtRate(2),
        ),
        _throwsIssue(OctojoinIssue.notEnoughAddresses),
      );
    });

    test('throws when inputs cannot cover payment plus fee', () {
      final tiny = [
        _utxo(sats: 100000, isSwapped: true),
        _utxo(sats: 100000, isSwapped: true, vout: 1),
        _utxo(sats: 50000, isSwapped: false, vout: 2),
      ];
      expect(
        () => Octojoin.plan(
          utxos: tiny,
          paymentSat: 305000,
          addresses: ['a', 'b'],
          numInputs: 3,
          feeForShape: _feeAtRate(10),
        ),
        _throwsIssue(OctojoinIssue.insufficientFunds),
      );
    });

    test('an absolute fee is used as-is when sizing the selection', () {
      final plan = Octojoin.plan(
        utxos: utxos,
        paymentSat: 300000,
        addresses: ['addrA', 'addrB'],
        numInputs: 3,
        feeForShape: (_, _) => 5000,
      );
      expect(plan.totalInputSat, greaterThanOrEqualTo(305000));
    });
  });
}
