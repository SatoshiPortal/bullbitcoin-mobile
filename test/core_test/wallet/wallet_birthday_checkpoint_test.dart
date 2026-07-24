import 'package:bb_mobile/core/wallet/domain/entities/wallet_birthday_checkpoint.dart';
import 'package:flutter_test/flutter_test.dart';

WalletBirthdayCheckpoint _build({
  DateTime? requestedBirthday,
  DateTime? blockTimestamp,
  int blockHeight = 0,
  String? blockHash,
}) {
  return WalletBirthdayCheckpoint(
    requestedBirthday: requestedBirthday ?? DateTime.utc(2026),
    blockTimestamp: blockTimestamp ?? DateTime.utc(2026),
    blockHeight: blockHeight,
    blockHash: blockHash ?? '0' * 64,
  );
}

void main() {
  group('WalletBirthdayCheckpoint validation', () {
    test('accepts a well-formed 64-char lowercase hex hash', () {
      expect(() => _build(blockHash: 'a' * 64), returnsNormally);
    });

    test('accepts height 0 (genesis)', () {
      expect(() => _build(blockHeight: 0), returnsNormally);
    });

    test('accepts a positive height', () {
      expect(() => _build(blockHeight: 900000), returnsNormally);
    });

    test('rejects a negative height', () {
      expect(() => _build(blockHeight: -1), throwsA(isA<ArgumentError>()));
    });

    test('rejects a hash shorter than 64 hex chars', () {
      expect(() => _build(blockHash: 'a' * 63), throwsA(isA<ArgumentError>()));
    });

    test('rejects a hash longer than 64 hex chars', () {
      expect(() => _build(blockHash: 'a' * 65), throwsA(isA<ArgumentError>()));
    });

    test('rejects an uppercase hash', () {
      expect(() => _build(blockHash: 'A' * 64), throwsA(isA<ArgumentError>()));
    });

    test('rejects a hash with a non-hex character', () {
      expect(() => _build(blockHash: 'g' * 64), throwsA(isA<ArgumentError>()));
    });
  });

  group('WalletBirthdayCheckpoint equality', () {
    test('two checkpoints with identical fields are equal', () {
      final a = _build();
      final b = _build();

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('checkpoints differing by blockHash are not equal', () {
      final a = _build(blockHash: '0' * 64);
      final b = _build(blockHash: 'f' * 64);

      expect(a, isNot(b));
    });

    test('checkpoints differing by blockHeight are not equal', () {
      final a = _build(blockHeight: 0);
      final b = _build(blockHeight: 1);

      expect(a, isNot(b));
    });
  });
}
