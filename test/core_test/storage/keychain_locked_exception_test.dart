import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/keychain_locked_exception.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isKeychainLocked', () {
    // The OSStatus has moved between fields across flutter_secure_storage
    // releases, and every caller that gets this wrong degrades into
    // "the key is gone" — which is the branch that offers to delete the
    // user's data. So all three shapes are pinned here.
    test('matches the status in `details`', () {
      expect(
        isKeychainLocked(PlatformException(code: 'x', details: -25308)),
        isTrue,
      );
    });

    test('matches the status in `code`', () {
      expect(isKeychainLocked(PlatformException(code: '-25308')), isTrue);
    });

    test('matches the status embedded in `message`', () {
      expect(
        isKeychainLocked(
          PlatformException(code: 'x', message: 'OSStatus -25308 returned'),
        ),
        isTrue,
      );
    });

    test('does not match an unrelated failure', () {
      expect(
        isKeychainLocked(
          PlatformException(code: 'x', message: 'item not found', details: -1),
        ),
        isFalse,
      );
    });
  });
}
