import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2640
// Finding: an exported browsable bitcoin: intent filter has no incoming-URI consumer.
// Regression test for the fix.
void main() {
  group('Security audit #2640 bitcoin URI routing', () {
    test('manifest does not advertise unhandled bitcoin links', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, isNot(contains('<data android:scheme="bitcoin" />')));
      expect(
        manifest,
        isNot(
          contains(
            '<category android:name="android.intent.category.BROWSABLE" />',
          ),
        ),
      );

      final sources = <String>[];
      for (final root in [
        Directory('lib'),
        Directory('android/app/src/main'),
      ]) {
        sources.addAll(
          root
              .listSync(recursive: true)
              .whereType<File>()
              .where(
                (file) =>
                    file.path.endsWith('.dart') ||
                    file.path.endsWith('.kt') ||
                    file.path.endsWith('.java'),
              )
              .map((file) => file.readAsStringSync()),
        );
      }
      final consumers = sources.join('\n');
      expect(consumers, isNot(contains('getIntent()')));
      expect(consumers, isNot(contains('onNewIntent')));
      // The payment parser supports bitcoin strings supplied by in-app flows;
      // this finding concerns Android intent delivery, not parser support.
      expect(consumers, isNot(contains('Intent.ACTION_VIEW')));
      expect(consumers, isNot(contains('android.intent.action.VIEW')));
    });
  });
}
