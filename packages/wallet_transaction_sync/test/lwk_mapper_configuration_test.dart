import 'dart:convert';

import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:test/test.dart';
import 'package:wallet_transaction_sync/src/data/lwk/lwk_wallet_transaction_mapper.dart';
import 'package:wallet_transaction_sync/src/data/lwk/lwk_wallet_transaction_source.dart';
import 'package:wallet_transaction_sync/wallet_transaction_sync.dart';

class _PublicValue implements lwk.TxOutSecrets {
  @override
  final BigInt value;
  @override
  final String asset;
  _PublicValue(int value, this.asset) : value = BigInt.from(value);
  @override
  String get valueBf => throw StateError('must not read value blinding factor');
  @override
  String get assetBf => throw StateError('must not read asset blinding factor');
}

class _Transaction implements lwk.Tx {
  @override
  final int? height;
  @override
  final int? timestamp;
  @override
  final String kind;
  @override
  final List<lwk.Balance> balances;
  @override
  final List<lwk.TxOut> outputs;
  @override
  final List<lwk.TxOut> inputs;
  @override
  final BigInt fee;
  @override
  final BigInt vsize = BigInt.from(321);
  @override
  final String txid = 'tx';
  _Transaction({
    this.height,
    this.timestamp,
    required this.kind,
    required this.balances,
    required this.outputs,
    required this.inputs,
    required this.fee,
  });
  @override
  String get unblindedUrl => throw StateError('must not read unblinding URL');
}

void main() {
  const lbtc = 'lbtc';
  const other = 'other';
  lwk.TxOut entry({
    required int index,
    required String asset,
    required int value,
  }) => lwk.TxOut(
    outpoint: lwk.OutPoint(txid: 'tx', vout: index),
    scriptPubkey: '0014script$index',
    address: lwk.Address(
      standard: 'standard$index',
      confidential: 'confidential$index',
      blindingKey: 'sentinel-secret',
    ),
    unblinded: _PublicValue(value, asset),
    isSpent: false,
  );
  lwk.Tx transaction({
    int? height,
    int? timestamp,
    String kind = 'outgoing',
    int balance = -700,
    int fee = 100,
  }) => _Transaction(
    height: height,
    timestamp: timestamp,
    kind: kind,
    balances: [
      lwk.Balance(assetId: lbtc, value: balance),
      const lwk.Balance(assetId: other, value: 99999),
    ],
    fee: BigInt.from(fee),
    inputs: [entry(index: 4, asset: other, value: 1)],
    outputs: [
      entry(index: 0, asset: lbtc, value: 500),
      entry(index: 3, asset: lbtc, value: 200),
      entry(index: 8, asset: other, value: 900),
    ],
  );

  test(
    'preserves vout gaps without inventing input positions, counts or chains',
    () {
      final mapped = mapLwkTransaction(
        transaction(),
        lbtcAssetId: lbtc,
        externalAddresses: {'standard0'},
      );
      expect(mapped.amountSats, 600);
      expect(mapped.feeSats, 100);
      expect(mapped.vsize, 321);
      expect(mapped.inputCount, isNull);
      expect(mapped.outputCount, isNull);
      expect(mapped.inputs.single.originalIndex, isNull);
      expect(mapped.inputs.single.vout, 4);
      expect(mapped.inputs.single.chain, isNull);
      expect(mapped.outputs.map((o) => o.originalIndex), [0, 3, 8]);
      expect(mapped.outputs[0].chain, TransactionChain.external);
      expect(mapped.outputs[1].chain, isNull);
      expect(mapped.outputs[1].vout, 3);
      expect(mapped.outputs[1].script, '0014script3');
      expect(mapped.outputs[1].isSpent, isFalse);
      expect(mapped.outputs[1].height, isNull);
    },
  );

  test(
    'self-transfer counts only positively matched external L-BTC outputs',
    () {
      final mapped = mapLwkTransaction(
        transaction(kind: 'redeposit', balance: -100),
        lbtcAssetId: lbtc,
        externalAddresses: {'confidential0', 'standard8'},
      );
      expect(mapped.selfTransfer, isTrue);
      expect(mapped.direction, TransactionDirection.outgoing);
      expect(mapped.amountSats, 500);
      expect(mapped.outputs[1].chain, isNull);
    },
  );

  test('incoming balance equal to fee is not a self-transfer', () {
    final mapped = mapLwkTransaction(
      transaction(kind: 'incoming', balance: 100),
      lbtcAssetId: lbtc,
    );
    expect(mapped.direction, TransactionDirection.incoming);
    expect(mapped.selfTransfer, isFalse);
    expect(mapped.amountSats, 100);
  });

  test('does not read or serialize unblinding factors, keys or URLs', () {
    final mapped = mapLwkTransaction(transaction(), lbtcAssetId: lbtc);
    final serialized = jsonEncode({
      'txid': mapped.txid,
      'amount': mapped.amountSats,
      'fee': mapped.feeSats,
      'vsize': mapped.vsize,
      'inputCount': mapped.inputCount,
      'outputCount': mapped.outputCount,
      'evidence': mapped.evidence,
      'details': mapped.details,
      'inputs': [
        for (final input in mapped.inputs)
          {
            'txid': input.txid,
            'vout': input.vout,
            'index': input.originalIndex,
            'value': input.value,
            'asset': input.assetId,
            'script': input.script,
            'standard': input.standardAddress,
            'confidential': input.confidentialAddress,
            'height': input.height,
            'spent': input.isSpent,
            'chain': input.chain?.name,
          },
      ],
      'outputs': [
        for (final output in mapped.outputs)
          {
            'txid': output.txid,
            'vout': output.vout,
            'index': output.originalIndex,
            'value': output.valueSats,
            'asset': output.assetId,
            'script': output.script,
            'standard': output.standardAddress,
            'confidential': output.confidentialAddress,
            'height': output.height,
            'spent': output.isSpent,
            'chain': output.chain?.name,
          },
      ],
    });
    expect(serialized, isNot(contains('sentinel-secret')));
    expect(mapped.details, isEmpty);
    expect(mapped.evidence, isEmpty);
  });

  test('uses source-reported confirmation without inventing chain proof', () {
    final mapped = mapLwkTransaction(
      transaction(height: 42, timestamp: 1700000000),
      lbtcAssetId: lbtc,
    );
    expect(mapped.position, isA<SourceReportedConfirmedPosition>());
    expect((mapped.position as SourceReportedConfirmedPosition).height, 42);
    expect(
      mapLwkTransaction(transaction(), lbtcAssetId: lbtc).position,
      isA<UnknownPosition>(),
    );
  });

  test('configuration identity and rendering are secret-safe', () {
    const descriptor = 'ct(sentinel-descriptor-secret)';
    final first = LwkElectrumConfiguration(
      confidentialPublicDescriptor: descriptor,
      isTestnet: true,
      electrumUrls: const ['ssl://one.example:995', 'ssl://two.example:995'],
      validateDomain: true,
      databaseRootPath: '/tmp/sentinel-path',
      timeout: 10,
      stopAtIndex: 20,
    );
    final moved = LwkElectrumConfiguration(
      confidentialPublicDescriptor: descriptor,
      isTestnet: true,
      electrumUrls: const ['ssl://different.example:995'],
      validateDomain: false,
      databaseRootPath: '/other/path',
      timeout: 99,
      stopAtIndex: 99,
    );
    expect(first.fingerprint, moved.fingerprint);
    expect('${first.toString()} ${first.toMap()}', isNot(contains(descriptor)));
    expect(first.toString(), isNot(contains('one.example')));
    expect(first.toString(), isNot(contains('/tmp')));
  });

  test('maps incompatible LWK state without exposing the SDK message', () {
    final failure = lwkStateIncompatibleFailure(
      const lwk.LwkError(
        msg: 'UpdateOnDifferentStatus sentinel-sensitive-source-message',
      ),
    );

    expect(failure, isA<WalletSourceStateIncompatibleFailure>());
    expect('$failure', isNot(contains('sentinel-sensitive-source-message')));
    expect(
      lwkStateIncompatibleFailure(const lwk.LwkError(msg: 'connection failed')),
      isNull,
    );
  });
}
