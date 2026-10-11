import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the allocator reserves only the 12-word backup index', () {
    for (final words in [12, 18, 24]) {
      expect(Bip85Reservations.nextMnemonicIndex(99, words: words), 99);
      expect(
        Bip85Reservations.nextMnemonicIndex(100, words: words),
        words == 12 ? 101 : 100,
      );
      expect(Bip85Reservations.nextMnemonicIndex(101, words: words), 101);
    }
    expect(
      () => Bip85Reservations.nextMnemonicIndex(0x80000000, words: 12),
      throwsFormatException,
    );
  });

  test('reserved paths stay private across their supported spellings', () {
    for (final path in [
      "39'/0'/12'/100'",
      "m/83696968'/39'/0'/12'/100'",
      '39h/0h/12h/100h',
      "39'/00'/12'/0100'",
      "128002'/100'/1'",
      "1642'/0'/1'",
      "1608'/0'/123'",
    ]) {
      expect(Bip85Reservations.isReservedPath(path), isTrue, reason: path);
    }
    for (final path in [
      "39'/0'/24'/100'",
      "39'/1'/12'/100'",
      "39'/0'/12'/101'",
      "128169'/32'/100'",
      "1608'/1'/123'",
    ]) {
      expect(Bip85Reservations.isReservedPath(path), isFalse, reason: path);
    }
  });
}
