import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

void main() {
  group('Fingerprint', () {
    test('accepts canonical lowercase hex', () {
      expect(Fingerprint('0a1b2c3d').hex, '0a1b2c3d');
    });

    test('rejects malformed constructor input', () {
      expect(() => Fingerprint('0A1B2C3D'), throwsArgumentError);
      expect(() => Fingerprint('0a1b2c'), throwsArgumentError);
      expect(() => Fingerprint('zzzzzzzz'), throwsArgumentError);
    });

    test('tryParse normalizes valid untrusted input', () {
      expect(Fingerprint.tryParse('DEADBEEF')?.hex, 'deadbeef');
      expect(Fingerprint.tryParse('nope'), isNull);
    });

    test('has value equality', () {
      expect(Fingerprint('abcdef01'), Fingerprint('abcdef01'));
      expect(Fingerprint('abcdef01'), isNot(Fingerprint('abcdef02')));
      expect({Fingerprint('abcdef01'), Fingerprint('abcdef01')}, hasLength(1));
    });
  });
}
