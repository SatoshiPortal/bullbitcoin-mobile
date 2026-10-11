import 'package:bb_mobile/features/sp/domain/sp_blindbit_lag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tip = 970180;

  SpBlindbitLag lagOf(int blocksBehind) =>
      SpBlindbitLag(blindbitTip: tip - blocksBehind, chainTip: tip);

  group('SpBlindbitLag.isBehind', () {
    test('a server at the tip is not behind', () {
      expect(lagOf(0).isBehind, isFalse);
    });

    test('a server up to the limit is not behind', () {
      expect(lagOf(spBlindbitMaxBlocksBehind).isBehind, isFalse);
    });

    test('a server past the limit is behind', () {
      expect(lagOf(spBlindbitMaxBlocksBehind + 1).isBehind, isTrue);
      expect(lagOf(1304).blocksBehind, 1304);
      expect(lagOf(1304).isBehind, isTrue);
    });

    test('a server ahead of the header tip is not behind', () {
      expect(lagOf(-10).isBehind, isFalse);
    });
  });

  test('rejects negative heights', () {
    expect(
      () => SpBlindbitLag(blindbitTip: -1, chainTip: tip),
      throwsArgumentError,
    );
    expect(
      () => SpBlindbitLag(blindbitTip: tip, chainTip: -1),
      throwsArgumentError,
    );
  });
}
