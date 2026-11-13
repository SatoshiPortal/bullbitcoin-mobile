import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:novlang/src/policy.dart';

void main() {
  group('resolveNovlangPolicy', () {
    const table = <(TargetPlatform, bool?, NovlangPolicy)>[
      (TargetPlatform.iOS, null, NovlangPolicy.apple),
      (TargetPlatform.iOS, false, NovlangPolicy.apple),
      (TargetPlatform.iOS, true, NovlangPolicy.none),
      (TargetPlatform.android, null, NovlangPolicy.google),
      (TargetPlatform.android, false, NovlangPolicy.google),
      (TargetPlatform.android, true, NovlangPolicy.none),
      (TargetPlatform.macOS, null, NovlangPolicy.none),
      (TargetPlatform.macOS, false, NovlangPolicy.none),
      (TargetPlatform.linux, null, NovlangPolicy.none),
      (TargetPlatform.windows, false, NovlangPolicy.none),
      (TargetPlatform.fuchsia, true, NovlangPolicy.none),
    ];

    for (final (platform, superuser, expected) in table) {
      test('$platform superuser=$superuser -> $expected', () {
        expect(resolveNovlangPolicy(platform, superuser), expected);
      });
    }
  });
}
