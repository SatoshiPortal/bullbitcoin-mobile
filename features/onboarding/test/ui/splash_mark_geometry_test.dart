import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onboarding/src/ui/widgets/splash_mark.dart';

/// Geometry and launch-resource parity for the startup loading splash.
///
/// The mark is one artwork in two places: four SVG files rendered by Flutter
/// and two Android vector drawables rendered by the platform launch screen.
/// These two must keep the same four `d` values and the same proportions, or
/// the hand-off from the native launch screen to the first Flutter frame
/// shifts the mark. Nothing here is a golden image: it compares source text and
/// asset bytes, so a retyped or re-exported path fails loudly.
void main() {
  final Directory repo = _repoRoot();
  final Directory res = Directory('${repo.path}/android/app/src/main/res');
  final Directory assets = Directory(
    '${repo.path}/features/onboarding/assets/splash',
  );

  /// `tl, tr, bl, br`.
  const List<String> shapes = <String>['tl', 'tr', 'bl', 'br'];

  String svgPathData(String shape) {
    final String source = File('${assets.path}/bb-mark-$shape.svg')
        .readAsStringSync();
    expect(
      source,
      contains('viewBox="0 0 2975 2512"'),
      reason: 'bb-mark-$shape.svg must keep the source viewBox',
    );
    final List<String> matches = _firstGroup(
      RegExp(r'<path d="([^"]+)"'),
      source,
    );
    expect(matches, hasLength(1), reason: 'bb-mark-$shape.svg holds one shape');
    expect(
      source,
      isNot(contains('fill=')),
      reason: 'the mark colour comes from the theme, not from the asset',
    );
    return matches.single;
  }

  List<String> vectorPathData(String file) {
    final String source = File('${res.path}/drawable/$file').readAsStringSync();
    return _firstGroup(RegExp(r'android:pathData="([^"]+)"'), source);
  }

  group('mark geometry', () {
    test('the four split SVGs carry the four distinct source shapes', () {
      final List<String> paths = shapes.map(svgPathData).toList();
      expect(paths.toSet(), hasLength(4));
      for (final String path in paths) {
        expect(path, startsWith('M '));
        expect(path, endsWith('Z'));
      }
    });

    test('the pre-12 Android vector uses the same four paths', () {
      final List<String> native = vectorPathData('splash_mark.xml');
      expect(native, hasLength(4));
      expect(native.toSet(), shapes.map(svgPathData).toSet());

      final String source = File('${res.path}/drawable/splash_mark.xml')
          .readAsStringSync();
      expect(source, contains('android:viewportWidth="2975"'));
      expect(source, contains('android:viewportHeight="2512"'));
      expect(source, contains('android:fillColor="#B7000B"'));
    });

    test('the Android 12 vector uses the same four paths', () {
      final List<String> native = vectorPathData('splash_mark_android12.xml');
      expect(native, hasLength(4));
      expect(native.toSet(), shapes.map(svgPathData).toSet());

      final String source = File(
        '${res.path}/drawable/splash_mark_android12.xml',
      ).readAsStringSync();
      expect(source, contains('android:viewportWidth="288"'));
      expect(source, contains('android:viewportHeight="288"'));
      expect(source, contains('android:fillColor="#B7000B"'));
      // Scaled so the mark's diagonal fills the 192 dp circle the platform
      // keeps visible on its 288 dp icon canvas.
      expect(source, contains('android:scaleX="0.049311"'));
      expect(source, contains('android:scaleY="0.049311"'));
    });

    test('the pre-12 vector keeps the Flutter mark size', () {
      final String source = File('${res.path}/drawable/splash_mark.xml')
          .readAsStringSync();
      final double height = const SplashMark().height;
      expect(height, 127);
      expect(source, contains('android:height="127dp"'));
      expect(
        source,
        contains(
          'android:width="${(height * SplashMark.aspectRatio).toStringAsFixed(2)}dp"',
        ),
      );
      expect(SplashMark.aspectRatio, closeTo(2975 / 2512, 1e-12));
    });
  });

  group('launch screen', () {
    test('Android 12+ shows the mark on graphite, with no red badge', () {
      for (final String variant in <String>['values-v31', 'values-night-v31']) {
        final String styles = File('${res.path}/$variant/styles.xml')
            .readAsStringSync();
        expect(
          styles,
          contains('android:windowSplashScreenBackground">#15171C<'),
          reason: variant,
        );
        expect(
          styles,
          contains(
            'android:windowSplashScreenAnimatedIcon">@drawable/splash_mark_android12<',
          ),
          reason: variant,
        );
        // The icon background colour is what paints the rejected red circle.
        expect(
          styles,
          isNot(contains('windowSplashScreenIconBackgroundColor')),
          reason: variant,
        );
      }
    });

    test('every theme keeps a graphite window behind Flutter', () {
      for (final String variant in <String>[
        'values',
        'values-night',
        'values-v31',
        'values-night-v31',
      ]) {
        final String styles = File('${res.path}/$variant/styles.xml')
            .readAsStringSync();
        expect(
          styles,
          contains('android:windowBackground">#15171C<'),
          reason: variant,
        );
        expect(
          styles,
          isNot(contains('?android:colorBackground')),
          reason: variant,
        );
      }
    });

    test('Android 12 removes the native splash instead of fading it out', () {
      final String activity = File(
        '${repo.path}/android/app/src/main/kotlin/com/bullbitcoin/bb_mobile/MainActivity.kt',
      ).readAsStringSync();
      final int listener = activity.indexOf('setOnExitAnimationListener');
      final int removal = activity.indexOf('splashScreenView.remove()');
      final int overlays = activity.indexOf('updateSystemUiOverlays()');
      final int parentCreate = activity.indexOf('super.onCreate');

      expect(activity, contains('Build.VERSION_CODES.S'));
      expect(listener, greaterThanOrEqualTo(0));
      expect(removal, greaterThan(listener));
      // remove() skips the platform exit that lets Flutter reapply its system
      // UI style, so the hand-off has to reapply the overlays right after it.
      expect(overlays, greaterThan(removal));
      expect(parentCreate, greaterThan(overlays));
    });

    test('pre-12 covers the page with the camo and centres the mark', () {
      for (final String variant in <String>['drawable', 'drawable-v21']) {
        final String background = File(
          '${res.path}/$variant/launch_background.xml',
        ).readAsStringSync();
        // Graphite base, the centre-cropped camo, then the mark centred on it.
        expect(
          background,
          contains('<color android:color="#15171C"/>'),
          reason: variant,
        );
        expect(
          background,
          contains('android:drawable="@drawable/splash_camo_cover"'),
          reason: variant,
        );
        expect(
          background,
          contains(
            '<item android:gravity="center" android:drawable="@drawable/splash_mark"/>',
          ),
          reason: variant,
        );
        // A <bitmap> gravity is not BoxFit.cover: fill_vertical fills one axis
        // only, fill stretches the square texture, tiling shows its seams.
        expect(background, isNot(contains('fill_vertical')), reason: variant);
        expect(background, isNot(contains('<bitmap')), reason: variant);
        expect(
          background,
          isNot(contains('android:tileMode')),
          reason: variant,
        );
      }
    });

    test('the pre-12 camo is drawn by a real centre-crop drawable', () {
      final String camo = File('${res.path}/drawable/splash_camo_cover.xml')
          .readAsStringSync();
      // The platform's custom-drawable hook: no-arg constructor + inflate().
      expect(
        camo,
        contains('class="com.bullbitcoin.mobile.CoverBitmapDrawable"'),
      );
      expect(camo, contains('android:src="@drawable/splash_camo"'));

      final String drawable = File(
        '${repo.path}/android/app/src/main/kotlin/com/bullbitcoin/bb_mobile/CoverBitmapDrawable.kt',
      ).readAsStringSync();
      // BoxFit.cover: one scale for both axes, the larger of the two ratios.
      expect(drawable, contains('kotlin.math.max'));
      expect(drawable, contains('area.width().toFloat() / source.width'));
      expect(drawable, contains('area.height().toFloat() / source.height'));
      // Centred on the bounds and cropped to them, never stretched.
      expect(drawable, contains('area.exactCenterX() - drawnWidth / 2f'));
      expect(drawable, contains('area.exactCenterY() - drawnHeight / 2f'));
      expect(drawable, contains('canvas.clipRect(area)'));
      // Inflated from android:src instead of a hardcoded resource.
      expect(drawable, contains('override fun inflate('));
      expect(drawable, contains('android.R.attr.src'));
      expect(drawable, contains('BitmapFactory.decodeResource('));
      // No non-null assertion: a missing android:src stays a no-op.
      expect(RegExp(r'!!').hasMatch(drawable), isFalse);
    });

    test('the rejected red and white launch resources are gone', () {
      final List<String> superseded = <String>[
        for (final String density in <String>[
          'mdpi',
          'hdpi',
          'xhdpi',
          'xxhdpi',
          'xxxhdpi',
        ]) ...<String>[
          'drawable-$density/android12splash.png',
          'drawable-night-$density/android12splash.png',
        ],
        'drawable/background.png',
        'drawable-v21/background.png',
      ];
      for (final String path in superseded) {
        expect(
          File('${res.path}/$path').existsSync(),
          isFalse,
          reason: '$path is superseded by the V3 launch screen',
        );
      }

      for (final FileSystemEntity entity in res.listSync(recursive: true)) {
        if (entity is! File) continue;
        if (!entity.path.endsWith('.xml')) continue;
        final String source = entity.readAsStringSync();
        expect(source, isNot(contains('android12splash')), reason: entity.path);
        expect(source, isNot(contains('#C50909')), reason: entity.path);
      }
    });
  });

  group('camo texture', () {
    test('Flutter and Android ship the same texture bytes', () {
      final Uint8List flutterAsset = File('${assets.path}/splash_camo.png')
          .readAsBytesSync();
      final Uint8List nativeAsset = File(
        '${res.path}/drawable-nodpi/splash_camo.png',
      ).readAsBytesSync();
      expect(nativeAsset, flutterAsset);
      expect(_pngWidth(nativeAsset), 512);
      expect(_pngHeight(nativeAsset), 512);
      // 8-bit RGB, no alpha channel: the texture is a full-page backdrop.
      expect(nativeAsset[24], 8);
      expect(nativeAsset[25], 2);
    });

    test('the documented source icon is the texture\'s graphite base', () {
      // The README derives the texture from this icon. Keeping the source in
      // the repository is what makes the provenance verifiable without a
      // design workspace.
      final Uint8List source = File(
        '${repo.path}/assets/logos/icon-black-red.png',
      ).readAsBytesSync();
      expect(_pngWidth(source), 512);
      expect(_pngHeight(source), 512);
      // 8-bit RGBA: the icon still carries the red bull the texture removes.
      expect(source[24], 8);
      expect(source[25], 6);
    });
  });

  test('the camo backdrop is a package asset of the loading splash', () {
    expect(File('${assets.path}/splash_camo.png').existsSync(), isTrue);
    final String pubspec = File('${repo.path}/features/onboarding/pubspec.yaml')
        .readAsStringSync();
    expect(pubspec, contains('assets/splash/'));
    expect(pubspec, contains('flutter_svg:'));
  });
}

/// Every capture of group 1. The patterns above make group 1 mandatory, so a
/// missing match is a test bug: fail on it instead of asserting non-null.
List<String> _firstGroup(RegExp pattern, String source) {
  final List<String> values = <String>[];
  for (final RegExpMatch match in pattern.allMatches(source)) {
    final String? value = match.group(1);
    if (value == null) {
      throw StateError('${pattern.pattern} matched without group 1');
    }
    values.add(value);
  }
  return values;
}

Directory _repoRoot() {
  Directory current = Directory.current.absolute;
  for (int i = 0; i < 6; i++) {
    if (Directory('${current.path}/android/app/src/main/res').existsSync() &&
        Directory('${current.path}/features/onboarding').existsSync()) {
      return current;
    }
    current = current.parent;
  }
  throw StateError('repository root not found from ${Directory.current.path}');
}

int _pngWidth(Uint8List bytes) => _uint32(bytes, 16);

int _pngHeight(Uint8List bytes) => _uint32(bytes, 20);

int _uint32(Uint8List bytes, int offset) =>
    ByteData.sublistView(bytes, offset, offset + 4).getUint32(0);
