import 'package:ark/src/data/bark_native_opener.dart';
import 'package:test/test.dart';

void main() {
  test('a Bark destination shows only its address', () {
    expect(
      movementDestinationValue('{"type":"bitcoin","value":"bcrt1pqk4ufh58"}'),
      'bcrt1pqk4ufh58',
    );
    expect(
      movementDestinationValue('{"type":"ark","value":"tark1qabc"}'),
      'tark1qabc',
    );
  });

  test('a plain or unexpected destination is kept as given', () {
    expect(movementDestinationValue('bcrt1qplain'), 'bcrt1qplain');
    expect(
      movementDestinationValue('{"type":"bitcoin"}'),
      '{"type":"bitcoin"}',
    );
  });
}
