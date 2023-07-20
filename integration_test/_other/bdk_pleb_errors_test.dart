import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:test/test.dart';

void main() {
  test('Error in mnemonics recovery', () async {
    const testSeed1SpellingAtIndex =
        'recipie path junior dune tragic target rocket inform thunder discover blue genre';
    final spellingIndexError = await bdk.Mnemonic.fromString(testSeed1SpellingAtIndex);
    print(spellingIndexError);
  });
}
