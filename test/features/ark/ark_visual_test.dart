import 'dart:io';
import 'dart:ui' as ui;

import 'package:bull_ui/app_theme.dart';
import 'package:bull_ark/ark_ui.dart' show ArkLocalizations;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:bull_ui/bull_ui.dart' show BullAmountScope, BullAmountSnapshot;

import '../../../features/ark/test/ark_visual_fixtures.dart';
import 'ark_shell_visual_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Home remembers the Ark balance it showed; here in memory.
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
      'Golos Text',
    )..addFont(rootBundle.load('assets/fonts/GolosText.ttf'))).load();
    await (FontLoader(
      'Bebas Neue',
    )..addFont(rootBundle.load('assets/fonts/BebasNeue-Regular.ttf'))).load();
  });
  for (final theme in AppThemeType.values) {
    testWidgets('render Ark audit ${theme.name}', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final output = Platform.environment['ARK_UI_OUTPUT'];
      Future<void> capture(
        String name,
        Widget screen, {
        Future<void> Function(WidgetTester)? arrange,
      }) async {
        stdout.writeln('Ark audit: $name ${theme.name}');
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            theme: AppTheme.themeData(theme),
            supportedLocales: ArkLocalizations.supportedLocales,
            localizationsDelegates: const [
              ArkLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            // Around the navigator, so a sheet over the screen is captured
            // and reads the same amount preferences.
            builder: (context, navigator) => RepaintBoundary(
              key: boundary,
              child: BullAmountScope(
                snapshot: const BullAmountSnapshot(
                  unit: BitcoinUnit.sats,
                  hideAmounts: false,
                  isReady: true,
                ),
                writeUnit: (_) async => false,
                child: navigator ?? const SizedBox.shrink(),
              ),
            ),
            home: screen,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        if (arrange != null) {
          await arrange(tester);
          await tester.pump();
        }
        expect(tester.takeException(), isNull, reason: name);
        final context = boundary.currentContext;
        if (context == null) throw StateError('Missing boundary for $name');
        final render = context.findRenderObject();
        if (render is! RenderRepaintBoundary) {
          throw StateError('Invalid boundary for $name');
        }
        if (output != null) {
          await tester.runAsync(() async {
            final image = await render.toImage(pixelRatio: 1);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            image.dispose();
            if (data == null) throw StateError('Missing PNG for $name');
            final file = File('$output/$name-${theme.name}.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data.buffer.asUint8List());
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }

      final shell = await ArkShellVisualFixtures.setUp();
      addTearDown(() => shell.tearDown().timeout(const Duration(seconds: 10)));
      await capture('Main', shell.settings());
      await capture('SendArkHome', shell.home());
      await captureArkVisualFixtures(capture);
    });
  }
}
