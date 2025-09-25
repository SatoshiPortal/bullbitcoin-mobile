import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/005_hive_to_sqlite.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('keyFromInternalDescriptor', () {
    test('extracts key between [ and 0/*', () {
      const descriptor =
          'wpkh(xpub6CGi7b6gV4igg6sYbhYV6s6AfsuQKfXpu5Bp6f4Puxmtst8Y2cAdaJLYoDr2krV1QnxZZsTtSvsGCpz2oddkaxQ3YepUntPLuU89HhMM4Vp/0/*)#xrz38kug';
      final result = fullKeyFromDescriptor(descriptor);
      expect(
        result,
        'xpub6CGi7b6gV4igg6sYbhYV6s6AfsuQKfXpu5Bp6f4Puxmtst8Y2cAdaJLYoDr2krV1QnxZZsTtSvsGCpz2oddkaxQ3YepUntPLuU89HhMM4Vp',
      );
    });
    test('extracts key between ( and 0/* if [ not present', () {
      const descriptor =
          'wpkh([abcd1234/84h/0h/0h]xpub6CUGRUonZSQ4TWtTMmzXdrXDtypWKiKp7z5zQ1R6jRg8z5p6h0/0/*)';
      final result = fullKeyFromDescriptor(descriptor);
      expect(
        result,
        '[abcd1234/84h/0h/0h]xpub6CUGRUonZSQ4TWtTMmzXdrXDtypWKiKp7z5zQ1R6jRg8z5p6h0',
      );
    });
    test('returns empty string if 0/* not found', () {
      const descriptor =
          'wpkh([abcd1234/84h/0h/0h]xpub6CUGRUonZSQ4TWtTMmzXdrXDtypWKiKp7z5zQ1R6jRg8z5p6h0/0/*)';
      final result = fullKeyFromDescriptor(descriptor);
      expect(
        result,
        '[abcd1234/84h/0h/0h]xpub6CUGRUonZSQ4TWtTMmzXdrXDtypWKiKp7z5zQ1R6jRg8z5p6h0',
      );
    });
  });
}
