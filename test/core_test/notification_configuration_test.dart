import 'dart:io';

import 'package:bb_mobile/core/notification_configuration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android notification icon is packaged as a drawable resource', () {
    final resourceRoot = Directory('android/app/src/main/res');
    final drawableResources = resourceRoot
        .listSync()
        .whereType<Directory>()
        .where(
          (directory) => directory.uri.pathSegments
              .where((segment) => segment.isNotEmpty)
              .last
              .startsWith('drawable'),
        )
        .expand((directory) => directory.listSync())
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last.split('.').first);

    expect(drawableResources, contains(androidNotificationIconResource));
  });
}
