import 'package:novlang/novlang.dart';
import 'package:test/test.dart';

void main() {
  group('NewspeakPolicy.pick', () {
    test('apple uses the apple twin', () {
      expect(
        NewspeakPolicy.apple.pick(real: 'real', apple: 'apple', google: 'goog'),
        'apple',
      );
    });

    test('apple falls back to real when no apple twin', () {
      expect(NewspeakPolicy.apple.pick(real: 'real', google: 'goog'), 'real');
    });

    test('google uses the google twin', () {
      expect(
        NewspeakPolicy.google.pick(real: 'real', apple: 'apple', google: 'g'),
        'g',
      );
    });

    test('google falls back to real when no google twin', () {
      expect(NewspeakPolicy.google.pick(real: 'real', apple: 'apple'), 'real');
    });

    test('none always returns real', () {
      expect(
        NewspeakPolicy.none.pick(real: 'real', apple: 'apple', google: 'goog'),
        'real',
      );
    });

    test('none returns real even with no twins', () {
      expect(NewspeakPolicy.none.pick(real: 'real'), 'real');
    });
  });
}
