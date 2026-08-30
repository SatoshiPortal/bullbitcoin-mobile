import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:flutter_test/flutter_test.dart';

lwk.WalletTxOutCompact _output({
  required BigInt value,
  required lwk.WalletTxChain chain,
  required int vout,
  String asset = 'lbtc-asset-id',
}) => lwk.WalletTxOutCompact(
  outpoint: lwk.OutPoint(txid: 'tx-id', vout: vout),
  scriptPubkey: 'script',
  standardAddress: 'standard-address',
  confidentialAddress: 'confidential-address',
  value: value,
  asset: asset,
  isSpent: false,
  chain: chain,
);

void main() {
  test('self-transfer amount excludes internal change outputs', () {
    final amount = liquidTransactionAmountSat(
      isToSelf: true,
      isIncoming: false,
      finalBalance: 100,
      feeSat: 100,
      lbtcAssetId: 'lbtc-asset-id',
      outputs: [
        _output(
          value: BigInt.from(1000),
          chain: lwk.WalletTxChain.external_,
          vout: 0,
        ),
        null,
        _output(
          value: BigInt.from(500),
          chain: lwk.WalletTxChain.internal,
          vout: 2,
        ),
      ],
    );

    expect(amount, 1000);
  });

  test('self-transfer amount ignores non-L-BTC outputs', () {
    final amount = liquidTransactionAmountSat(
      isToSelf: true,
      isIncoming: false,
      finalBalance: 100,
      feeSat: 100,
      lbtcAssetId: 'lbtc-asset-id',
      outputs: [
        _output(
          value: BigInt.from(1000),
          chain: lwk.WalletTxChain.external_,
          vout: 0,
        ),
        _output(
          value: BigInt.from(9000),
          chain: lwk.WalletTxChain.external_,
          vout: 1,
          asset: 'other-asset-id',
        ),
        _output(
          value: BigInt.from(500),
          chain: lwk.WalletTxChain.internal,
          vout: 2,
        ),
        _output(
          value: BigInt.from(8000),
          chain: lwk.WalletTxChain.internal,
          vout: 3,
          asset: 'other-asset-id',
        ),
      ],
    );

    expect(amount, 1000);
  });

  test('requests unblinding data only for exact transaction details', () {
    expect(includeUnblindingDataForTransaction(txId: null), isFalse);
    expect(includeUnblindingDataForTransaction(txId: 'tx-id'), isTrue);
  });
}
