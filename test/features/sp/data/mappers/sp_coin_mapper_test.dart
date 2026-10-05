import 'package:bb_mobile/features/sp/data/mappers/sp_coin_mapper.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:bull_sdk/bwk.dart' as bwk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  group('SpCoinMapper.parseOutpoint', () {
    test('splits a txid and vout on the last colon', () {
      expect(SpCoinMapper.parseOutpoint('abcdef:3'), (txId: 'abcdef', vout: 3));
    });

    test('accepts vout zero', () {
      expect(SpCoinMapper.parseOutpoint('abcdef:0').vout, 0);
    });

    test('throws when there is no vout separator', () {
      expect(
        () => SpCoinMapper.parseOutpoint('abcdef'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws when the vout is not a number', () {
      expect(
        () => SpCoinMapper.parseOutpoint('abcdef:x'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws when the vout is empty', () {
      expect(
        () => SpCoinMapper.parseOutpoint('abcdef:'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('SpCoinMapper.sourceToDomain', () {
    test('maps every bwk coin source', () {
      expect(SpCoinMapper.sourceToDomain(bwk.CoinSource.sp), SpCoinSource.sp);
      expect(
        SpCoinMapper.sourceToDomain(bwk.CoinSource.segwit),
        SpCoinSource.segwit,
      );
      expect(
        SpCoinMapper.sourceToDomain(bwk.CoinSource.taproot),
        SpCoinSource.taproot,
      );
      expect(
        SpCoinMapper.sourceToDomain(bwk.CoinSource.other),
        SpCoinSource.other,
      );
    });
  });

  group('SpCoinMapper.toDomain', () {
    test('maps a confirmed unspent coin', () {
      final coin = SpCoinMapper.toDomain(
        bwk.UnifiedCoinView(
          source: bwk.CoinSource.sp,
          outpoint: 'abcdef:1',
          amountSat: BigInt.from(12345),
          height: 800000,
          status: bwk.UnifiedCoinStatus.unspent,
        ),
      );

      expect(coin.source, SpCoinSource.sp);
      expect(coin.outpoint, (txId: 'abcdef', vout: 1));
      expect(coin.amountSat, Sats.fromInt(12345));
      expect(coin.height, 800000);
      expect(coin.status, SpCoinStatus.unspent);
    });

    test('maps an unconfirmed coin with no height', () {
      final coin = SpCoinMapper.toDomain(
        bwk.UnifiedCoinView(
          source: bwk.CoinSource.taproot,
          outpoint: 'abcdef:0',
          amountSat: BigInt.zero,
          status: bwk.UnifiedCoinStatus.unconfirmed,
        ),
      );

      expect(coin.height, isNull);
      expect(coin.status, SpCoinStatus.unconfirmed);
      expect(coin.amountSat, Sats.zero);
    });

    test('maps a spent coin', () {
      final coin = SpCoinMapper.toDomain(
        bwk.UnifiedCoinView(
          source: bwk.CoinSource.segwit,
          outpoint: 'abcdef:2',
          amountSat: BigInt.from(1),
          height: 1,
          status: bwk.UnifiedCoinStatus.spent,
        ),
      );

      expect(coin.status, SpCoinStatus.spent);
      expect(coin.source, SpCoinSource.segwit);
    });

    test('rejects a coin whose outpoint has no vout', () {
      expect(
        () => SpCoinMapper.toDomain(
          bwk.UnifiedCoinView(
            source: bwk.CoinSource.sp,
            outpoint: 'abcdef',
            amountSat: BigInt.from(1),
            status: bwk.UnifiedCoinStatus.unspent,
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
