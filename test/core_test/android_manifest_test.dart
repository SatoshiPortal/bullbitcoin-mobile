import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MainActivity can receive gallery picker activity results', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final activity = RegExp(
      r'<activity\s[^>]*android:name="com\.bullbitcoin\.mobile\.MainActivity"[^>]*>',
    ).firstMatch(manifest);
    expect(activity, isNotNull);

    final launchMode = RegExp(
      r'android:launchMode="([^"]+)"',
    ).firstMatch(activity!.group(0)!)?.group(1);

    // image_picker documents that singleInstance always returns RESULT_CANCELED.
    // https://pub.dev/packages/image_picker/versions/1.2.3#using-launchmode-singleinstance
    expect(
      launchMode ?? 'standard',
      isIn(['standard', 'singleTop', 'singleTask']),
      reason: 'Gallery activities must return their result to MainActivity.',
    );
  });
}
