import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

const coinTxId =
    '0000000000000000000000000000000000000000000000000000000000000abc';

SpCoin buildCoin({String txId = coinTxId, int vout = 0, int? height = 100}) {
  return SpCoin(
    source: SpCoinSource.sp,
    outpoint: (txId: txId, vout: vout),
    amountSat: Sats.fromInt(1000),
    height: height,
    status: SpCoinStatus.unspent,
  );
}

void main() {
  group('SpCoin invariants', () {
    test('accepts a well formed coin', () {
      final coin = buildCoin();

      expect(coin.outpoint.txId, coinTxId);
      expect(coin.outpoint.vout, 0);
      expect(coin.amountSat, Sats.fromInt(1000));
      expect(coin.height, 100);
      expect(coin.status, SpCoinStatus.unspent);
      expect(coin.source, SpCoinSource.sp);
    });

    test('rejects an empty txId', () {
      expect(() => buildCoin(txId: ''), throwsA(isA<ArgumentError>()));
    });

    test('rejects a negative vout', () {
      expect(() => buildCoin(vout: -1), throwsA(isA<ArgumentError>()));
    });

    test('rejects a negative height', () {
      expect(() => buildCoin(height: -1), throwsA(isA<ArgumentError>()));
    });

    test('accepts a null height for an unconfirmed coin', () {
      expect(buildCoin(height: null).height, isNull);
    });

    test('accepts height zero', () {
      expect(buildCoin(height: 0).height, 0);
    });
  });
}
