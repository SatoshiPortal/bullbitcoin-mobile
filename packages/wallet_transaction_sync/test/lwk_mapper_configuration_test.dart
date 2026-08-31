import 'dart:convert';

import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:test/test.dart';
import 'package:wallet_transaction_sync/src/data/lwk/lwk_wallet_transaction_mapper.dart';
import 'package:wallet_transaction_sync/src/data/lwk/lwk_wallet_transaction_source.dart';
import 'package:wallet_transaction_sync/wallet_transaction_sync.dart';

void main() {
  const lbtc = 'lbtc';
  const other = 'asset-2';

  lwk.WalletTxOutCompact entry({
    required int index,
    required String asset,
    required int value,
    lwk.WalletTxChain chain = lwk.WalletTxChain.external_,
    bool spent = false,
    int? height,
  }) => lwk.WalletTxOutCompact(
    outpoint: lwk.OutPoint(txid: 'tx', vout: index),
    scriptPubkey: '0014script$index',
    standardAddress: 'el1standard$index',
    confidentialAddress: 'el1confidential$index',
    value: BigInt.from(value),
    asset: asset,
    isSpent: spent,
    height: height,
    chain: chain,
  );

  lwk.WalletTxProjection projection({
    int? height,
    int? timestamp,
    String kind = 'outgoing',
    int lbtcBalance = -700,
    List<lwk.WalletTxOutCompact?>? outputs,
  }) => lwk.WalletTxProjection(
    txid: 'tx',
    timestamp: timestamp,
    kind: kind,
    balances: [
      lwk.Balance(assetId: lbtc, value: lbtcBalance),
      const lwk.Balance(assetId: other, value: 999999),
    ],
    fee: BigInt.from(100),
    height: height,
    unblindedUrl: 'https://secret.example/sentinel-secret',
    vsize: BigInt.from(321),
    inputs: [
      entry(index: 4, asset: other, value: 1),
      null,
    ],
    outputs:
        outputs ??
        [
          entry(index: 0, asset: lbtc, value: 500),
          entry(
            index: 1,
            asset: lbtc,
            value: 200,
            chain: lwk.WalletTxChain.internal,
          ),
          entry(index: 2, asset: other, value: 900),
        ],
  );

  test('maps Liquid fields, preserves slots, and filters amount assets', () {
    final mapped = mapLwkTransaction(projection(), lbtcAssetId: lbtc);

    expect(mapped.amountSats, 600);
    expect(mapped.feeSats, 100);
    expect(mapped.vsize, 321);
    expect(mapped.inputCount, 2);
    expect(mapped.outputCount, 3);
    expect(mapped.inputs.single.originalIndex, 0);
    expect(mapped.inputs.single.txid, 'tx');
    expect(mapped.inputs.single.value, 1);
    expect(mapped.inputs.single.chain, TransactionChain.external);
    expect(mapped.outputs, hasLength(3));
    expect(mapped.outputs[1].chain, TransactionChain.internal);
    expect(mapped.outputs[1].isSpent, isFalse);
    expect(mapped.outputs[1].assetId, lbtc);
    expect(mapped.outputs[2].assetId, other);
    expect(mapped.outputs[0].standardAddress, 'el1standard0');
    expect(mapped.outputs[0].txid, 'tx');
    expect(mapped.outputs[0].vout, 0);
    expect(mapped.outputs[0].script, '0014script0');
    expect(mapped.outputs[0].height, isNull);
    final mappedData = jsonEncode({
      'tx': mapped.txid,
      'evidence': mapped.evidence,
      'details': mapped.details,
      'inputs': mapped.inputs
          .map(
            (input) => {
              'txid': input.txid,
              'asset': input.assetId,
              'address': input.confidentialAddress,
            },
          )
          .toList(),
      'outputs': mapped.outputs
          .map(
            (output) => {
              'asset': output.assetId,
              'address': output.confidentialAddress,
            },
          )
          .toList(),
    });
    expect(mappedData, isNot(contains('sentinel-secret')));
    expect('$mapped', isNot(contains('sentinel-secret')));
  });

  test('self-transfer excludes internal L-BTC change and other assets', () {
    final mapped = mapLwkTransaction(
      projection(
        kind: 'redeposit',
        lbtcBalance: -100,
        outputs: [
          entry(index: 0, asset: lbtc, value: 500),
          entry(
            index: 1,
            asset: lbtc,
            value: 200,
            chain: lwk.WalletTxChain.internal,
          ),
          entry(index: 2, asset: other, value: 900),
        ],
      ),
      lbtcAssetId: lbtc,
    );

    expect(mapped.selfTransfer, isTrue);
    expect(mapped.direction, TransactionDirection.outgoing);
    expect(mapped.amountSats, 500);
  });

  test('uses confirmed and unknown positions without inventing proof', () {
    final confirmed = mapLwkTransaction(
      projection(height: 42, timestamp: 1700000000),
      lbtcAssetId: lbtc,
    );
    expect(confirmed.position, isA<SourceReportedConfirmedPosition>());
    expect((confirmed.position as SourceReportedConfirmedPosition).height, 42);
    expect(
      (confirmed.position as SourceReportedConfirmedPosition).time,
      isNotNull,
    );
    expect(
      mapLwkTransaction(projection(), lbtcAssetId: lbtc).position,
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
