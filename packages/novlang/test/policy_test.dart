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

  group('resolveNovlangPolicy with the Apple wording forced', () {
    // forced: Apple on every platform, except that the superuser stays first.
    for (final platform in TargetPlatform.values) {
      for (final (superuser, expected) in <(bool?, NovlangPolicy)>[
        (null, NovlangPolicy.apple),
        (false, NovlangPolicy.apple),
        (true, NovlangPolicy.none),
      ]) {
        test('$platform superuser=$superuser force -> $expected', () {
          expect(
            resolveNovlangPolicy(platform, superuser, forceApple: true),
            expected,
          );
        });
      }
    }

    test('not forced behaves as the plain platform policy', () {
      for (final platform in TargetPlatform.values) {
        for (final superuser in <bool?>[null, false, true]) {
          expect(
            resolveNovlangPolicy(platform, superuser, forceApple: false),
            resolveNovlangPolicy(platform, superuser),
          );
        }
      }
    });
  });
}
