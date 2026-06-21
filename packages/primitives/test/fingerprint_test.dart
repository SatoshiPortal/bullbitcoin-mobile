import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

void main() {
  group('Fingerprint constructor (throwing — programmer-bug bucket)', () {
    test('accepts 8 lowercase hex chars', () {
      expect(Fingerprint('0a1b2c3d').hex, '0a1b2c3d');
    });

    test('rejects uppercase', () {
      expect(() => Fingerprint('0A1B2C3D'), throwsArgumentError);
    });

    test('rejects wrong length', () {
      expect(() => Fingerprint('0a1b2c'), throwsArgumentError);
      expect(() => Fingerprint('0a1b2c3d4'), throwsArgumentError);
    });

    test('rejects non-hex', () {
      expect(() => Fingerprint('zzzzzzzz'), throwsArgumentError);
    });
  });

  group('Fingerprint.tryParse (non-throwing — untrusted input)', () {
    test('returns a Fingerprint for valid input', () {
      expect(Fingerprint.tryParse('deadbeef')?.hex, 'deadbeef');
    });

    test('returns null for invalid input instead of throwing', () {
      expect(Fingerprint.tryParse('DEADBEEF'), isNull);
      expect(Fingerprint.tryParse('nope'), isNull);
      expect(Fingerprint.tryParse(''), isNull);
    });
  });

  group('value equality', () {
    test('equal hex compares equal and hashes equal', () {
      expect(Fingerprint('abcdef01'), Fingerprint('abcdef01'));
      expect(
        Fingerprint('abcdef01').hashCode,
        Fingerprint('abcdef01').hashCode,
      );
    });

    test('different hex compares unequal', () {
      expect(Fingerprint('abcdef01'), isNot(Fingerprint('abcdef02')));
    });
  });
}
