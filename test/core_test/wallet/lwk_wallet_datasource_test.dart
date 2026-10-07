import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:flutter_test/flutter_test.dart';

lwk.TxOut _output(int value, int vout, {String asset = 'lbtc'}) => lwk.TxOut(
  outpoint: lwk.OutPoint(txid: 'tx', vout: vout),
  scriptPubkey: 'script',
  address: lwk.Address(
    standard: 'standard$vout',
    confidential: 'confidential$vout',
  ),
  unblinded: lwk.TxOutSecrets(
    value: BigInt.from(value),
    asset: asset,
    valueBf: 'unused',
    assetBf: 'unused',
  ),
  isSpent: false,
);

void main() {
  test(
    'self-transfer counts only external-address matches in the policy asset',
    () {
      expect(
        liquidTransactionAmountSat(
          isToSelf: true,
          isIncoming: false,
          finalBalance: -100,
          feeSat: 100,
          lbtcAssetId: 'lbtc',
          outputs: [
            _output(1000, 0),
            _output(500, 3),
            _output(9000, 8, asset: 'other'),
          ],
          externalAddresses: {'confidential0', 'standard8'},
        ),
        1000,
      );
    },
  );

  test('incoming and outgoing amounts use net balance and fees', () {
    for (final incoming in [true, false]) {
      expect(
        liquidTransactionAmountSat(
          isToSelf: false,
          isIncoming: incoming,
          finalBalance: incoming ? 1000 : -1100,
          feeSat: 100,
          lbtcAssetId: 'lbtc',
          outputs: [],
          externalAddresses: {},
        ),
        1000,
      );
    }
  });

  test('an unmatched output is not assumed to be an external recipient', () {
    expect(
      liquidTransactionAmountSat(
        isToSelf: true,
        isIncoming: false,
        finalBalance: -100,
        feeSat: 100,
        lbtcAssetId: 'lbtc',
        outputs: [_output(500, 3)],
        externalAddresses: {},
      ),
      0,
    );
  });
}
