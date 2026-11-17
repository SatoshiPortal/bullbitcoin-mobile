import 'package:rust_bindings/lwk.dart' as lwk;
import 'package:flutter_test/flutter_test.dart';
import 'package:sync/src/data/write/spend/native_spend.dart';
import 'package:sync/sync.dart';

// The LWK library is not built for unit tests: this fake records the builder
// calls the Liquid spend makes. Ported from the app's datasource tests when
// the builds moved into sync.

const _asset = 'lbtc';

final class _Wallet implements lwk.Wallet {
  List<lwk.TxOut> coins = [];
  Object? buildError;
  lwk.Address lastUnused = const lwk.Address(
    standard: '',
    confidential: '',
    index: 4,
  );
  final custom =
      <
        ({
          List<lwk.OutPoint> utxos,
          List<lwk.TxOutputSpec> outputs,
          String? drainTo,
          double feeRate,
        })
      >[];
  final automatic =
      <({BigInt sats, String outAddress, double feeRate, bool drain})>[];

  @override
  Future<String> policyAsset() async => _asset;

  @override
  Future<List<lwk.TxOut>> utxos() async => coins;

  @override
  Future<lwk.Address> addressLastUnused() async => lastUnused;

  @override
  Future<lwk.Address> address({required int index}) async =>
      lwk.Address(standard: '', confidential: 'recipient-$index', index: index);

  @override
  Future<String> buildCustomTx({
    required List<lwk.OutPoint> utxos,
    required List<lwk.TxOutputSpec> outputs,
    String? drainTo,
    required double feeRate,
  }) async {
    custom.add((
      utxos: utxos,
      outputs: outputs,
      drainTo: drainTo,
      feeRate: feeRate,
    ));
    final error = buildError;
    if (error != null) throw error;
    return 'pset-${custom.length}';
  }

  @override
  Future<String> buildLbtcTx({
    required BigInt sats,
    required String outAddress,
    required double feeRate,
    required bool drain,
  }) async {
    automatic.add((
      sats: sats,
      outAddress: outAddress,
      feeRate: feeRate,
      drain: drain,
    ));
    final error = buildError;
    if (error != null) throw error;
    return 'pset';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

lwk.TxOut _coin(String txid, {String asset = _asset, int? height = 100}) =>
    lwk.TxOut(
      scriptPubkey: 'script',
      outpoint: lwk.OutPoint(txid: txid, vout: 0),
      height: height,
      unblinded: lwk.TxOutSecrets(
        value: BigInt.from(20000),
        valueBf: '',
        asset: asset,
        assetBf: '',
      ),
      isSpent: false,
      address: const lwk.Address(standard: 's', confidential: 'c'),
    );

void main() {
  late _Wallet wallet;
  late NativeLiquidSpend spend;
  final fee = SpendFeeRate(25);

  setUp(() {
    wallet = _Wallet();
    spend = liquidSpendOver(wallet);
  });

  Matcher refusal<T extends SyncFailure>() => throwsA(
    isA<SpendRefusal>().having((r) => r.failure, 'failure', isA<T>()),
  );

  test('builds a fixed output from the given inputs only', () async {
    await spend.build(
      LiquidSpendRequest(address: 'recipient', amountSat: 20000, fee: fee),
      {(txId: 'selected', vout: 1)},
    );
    expect(wallet.custom.single.utxos, [
      const lwk.OutPoint(txid: 'selected', vout: 1),
    ]);
    expect(wallet.custom.single.outputs, [
      lwk.TxOutputSpec(address: 'recipient', satoshi: BigInt.from(20000)),
    ]);
    // 25 sat/kwu is exactly 100 sat/kvB.
    expect(wallet.custom.single.feeRate, 100);
    expect(wallet.automatic, isEmpty);
  });

  test('drains the given inputs without a fixed output', () async {
    await spend.build(LiquidSpendRequest(address: 'recipient', fee: fee), {
      (txId: 'selected', vout: 1),
    });
    expect(wallet.custom.single.outputs, isEmpty);
    expect(wallet.custom.single.drainTo, 'recipient');
  });

  test('keeps LWK\'s own selection when no input is given', () async {
    await spend.build(
      LiquidSpendRequest(address: 'recipient', amountSat: 20000, fee: fee),
      null,
    );
    expect(wallet.automatic.single.sats, BigInt.from(20000));
    expect(wallet.automatic.single.drain, isFalse);
    expect(wallet.custom, isEmpty);
  });

  test('reports a shortfall without retrying another selection', () async {
    wallet.buildError = const lwk.LwkError(msg: 'InsufficientFunds { .. }');
    await expectLater(
      spend.build(
        LiquidSpendRequest(address: 'recipient', amountSat: 20000, fee: fee),
        {(txId: 'selected', vout: 1)},
      ),
      refusal<SyncInsufficientFundsFailure>(),
    );
    expect(wallet.automatic, isEmpty);
  });

  test(
    'more inputs than one transaction holds call for consolidation',
    () async {
      wallet.buildError = const lwk.LwkError(msg: 'too many inputs');
      await expectLater(
        spend.build(
          LiquidSpendRequest(address: 'recipient', amountSat: 20000, fee: fee),
          {for (var i = 0; i < 257; i++) (txId: 'coin', vout: i)},
        ),
        refusal<SyncConsolidationRequiredFailure>(),
      );
    },
  );

  test('keeps an unclassified LWK error as it is', () async {
    const error = lwk.LwkError(msg: 'unclassified');
    wallet.buildError = error;
    await expectLater(
      spend.build(
        LiquidSpendRequest(address: 'recipient', amountSat: 1000, fee: fee),
        {(txId: 'selected', vout: 1)},
      ),
      throwsA(same(error)),
    );
  });

  test('lists confirmed state for policy-asset coins only', () async {
    wallet.coins = [
      _coin('lbtc'),
      _coin('pending', height: null),
      _coin('other', asset: 'other'),
    ];
    expect(await spend.coins(), [
      (outpoint: (txId: 'lbtc', vout: 0), confirmed: true),
      (outpoint: (txId: 'pending', vout: 0), confirmed: false),
    ]);
  });

  test('consolidates the given coins in bounded batches from the next '
      'unused address', () async {
    final psets = await spend.consolidate(
      ConsolidationRequest(fee: fee, highUtxoThreshold: 0, maximumInputs: 2),
      [
        for (final id in ['first', 'second', 'third']) (txId: id, vout: 0),
      ],
    );
    expect(psets, hasLength(2));
    expect(
      [for (final call in wallet.custom) call.utxos],
      [
        [
          const lwk.OutPoint(txid: 'first', vout: 0),
          const lwk.OutPoint(txid: 'second', vout: 0),
        ],
        [const lwk.OutPoint(txid: 'third', vout: 0)],
      ],
    );
    expect(
      [for (final call in wallet.custom) call.drainTo],
      ['recipient-4', 'recipient-5'],
    );
  });

  test('a missing consolidation address index builds nothing', () async {
    wallet.lastUnused = const lwk.Address(standard: '', confidential: '');
    await expectLater(
      spend.consolidate(
        ConsolidationRequest(fee: fee, highUtxoThreshold: 0, maximumInputs: 2),
        [(txId: 'first', vout: 0)],
      ),
      throwsA(isA<Exception>()),
    );
    expect(wallet.custom, isEmpty);
  });
}
