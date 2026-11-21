import 'package:preferences/src/domain/settings_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Language.fromLocaleTags', () {
    test('prefers an exact country match over the first language match', () {
      expect(
        Language.fromLocaleTags(languageCode: 'pt', countryCode: 'BR'),
        Language.brazilianPortuguese,
      );
    });

    test('prefers an exact script match over the first language match', () {
      expect(
        Language.fromLocaleTags(languageCode: 'hi', scriptCode: 'Latn'),
        Language.hinglish,
      );
    });

    test('uses the first language match when the subtags do not match', () {
      expect(
        Language.fromLocaleTags(languageCode: 'pt', countryCode: 'AO'),
        Language.portuguese,
      );
    });

    test('defaults to United States English for an unsupported language', () {
      expect(
        Language.fromLocaleTags(languageCode: 'ja', countryCode: 'JP'),
        Language.unitedStatesEnglish,
      );
    });
  });
}
