import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('does not inspect installed app identities', () {
    final productRoots = [
      Directory('lib'),
      Directory('packages'),
      Directory('android/app/src'),
    ];
    const sourceExtensions = {
      '.dart',
      '.gradle',
      '.java',
      '.kt',
      '.swift',
      '.xml',
      '.yaml',
    };
    const forbiddenMarkers = {
      'android.permission.QUERY_ALL_PACKAGES',
      'getInstalledApplications(',
      'getInstalledPackages(',
      'getLaunchIntentForPackage(',
      'org.torproject.android',
    };

    for (final root in productRoots) {
      if (!root.existsSync()) continue;
      for (final file in root.listSync(recursive: true).whereType<File>()) {
        if (!sourceExtensions.any(file.path.endsWith)) continue;
        final contents = file.readAsStringSync();
        for (final marker in forbiddenMarkers) {
          expect(
            contents,
            isNot(contains(marker)),
            reason: 'Installed-app discovery marker found in ${file.path}',
          );
        }
      }
    }

    expect(Directory('packages/bull_tor/android').existsSync(), isFalse);
    expect(
      File(
        'lib/features/tor_settings/ui/widgets/tor_proxy_widget.dart',
      ).readAsStringSync(),
      isNot(contains('canLaunchUrl')),
    );
  });
}
