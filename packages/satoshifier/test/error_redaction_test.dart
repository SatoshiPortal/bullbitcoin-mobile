import 'package:flutter_test/flutter_test.dart';
import 'package:satoshifier/satoshifier.dart';

void main() {
  // Synthetic, deliberately not real key material: what matters here is
  // whether the value survives into the thrown error, not whether it decodes.
  const fakeMnemonic =
      'sample sample sample sample sample sample '
      'sample sample sample sample sample synthetic';
  const fakeXprv =
      'xprvSYNTHETICnotarealkey00000000000000000000000'
      '00000000000000000000000000000000000000000000';
  const fakeDescriptor =
      'wpkh([zzzzzzzz/84h/0h/0h]xprvSYNTHETICnotarealkey/0/*)';

  Future<String> errorFor(String input) async {
    try {
      await Satoshifier.parse(input);
      fail('expected $input to fail parsing');
    } catch (e) {
      return e.toString();
    }
  }

  group('parse failures do not echo the input', () {
    // A user pasting a seed phrase or private key into a send field is an
    // ordinary mistake. Host apps route uncaught errors to crash reporting, so
    // anything embedded in the message is persisted outside the app.
    test('a mnemonic is not echoed', () async {
      final message = await errorFor(fakeMnemonic);
      expect(message, isNot(contains('synthetic')));
      expect(message, isNot(contains(fakeMnemonic)));
    });

    test('an extended private key is not echoed', () async {
      final message = await errorFor(fakeXprv);
      expect(message, isNot(contains(fakeXprv)));
      expect(message, isNot(contains('SYNTHETICnotarealkey')));
    });

    test('a descriptor carrying a private key is not echoed', () async {
      final message = await errorFor(fakeDescriptor);
      expect(message, isNot(contains('SYNTHETICnotarealkey')));
    });

    // Reached by Descriptor.parse before any shape matching, so a malformed
    // paste that happens to carry a key lands here routinely.
    test('a descriptor rejected for its checksum is not echoed', () {
      const withBadChecksum =
          'wpkh([86241f88/84h/0h/0h]xprvSYNTHETICnotarealkey/0/*)#aaaaaaaa';
      expect(
        () => Descriptor.parse(withBadChecksum),
        throwsA(
          predicate((e) => !e.toString().contains('SYNTHETICnotarealkey')),
        ),
      );
    });

    test('the failure is still identifiable', () async {
      final message = await errorFor(fakeXprv);
      expect(message, isNotEmpty);
      expect(message.toLowerCase(), contains('parse'));
    });
  });
}
