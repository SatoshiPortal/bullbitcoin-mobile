import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('configured activities can receive gallery picker activity results', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final activity = RegExp(
      r'<activity\s[^>]*android:name="\$\{mainActivity\}"[^>]*>',
    ).firstMatch(manifest);
    expect(activity, isNotNull);

    final launchMode = RegExp(r'android:launchMode="([^"]+)"')
        .firstMatch(activity?.group(0) ?? '')
        ?.group(1);

    // image_picker documents that singleInstance always returns RESULT_CANCELED.
    // https://pub.dev/packages/image_picker/versions/1.2.3#using-launchmode-singleinstance
    expect(
      launchMode ?? 'standard',
      isIn(['standard', 'singleTop', 'singleTask']),
      reason:
          'Gallery activities must return their result to the app activity.',
    );

    final gradle = File('android/app/build.gradle').readAsStringSync();
    expect(
      gradle,
      contains(
        "manifestPlaceholders['mainActivity'] = 'com.bullbitcoin.mobile.MainActivity'",
      ),
    );
    expect(
      gradle,
      contains(
        "manifestPlaceholders['mainActivity'] = 'com.bullbitcoin.mobile.RecoverBullPasskeyActivity'",
      ),
    );
    final debugActivity = File(
      'android/app/src/debug/kotlin/com/bullbitcoin/mobile/RecoverBullPasskeyActivity.kt',
    ).readAsStringSync();
    expect(
      debugActivity,
      contains('class RecoverBullPasskeyActivity : MainActivity()'),
    );
  });
}
