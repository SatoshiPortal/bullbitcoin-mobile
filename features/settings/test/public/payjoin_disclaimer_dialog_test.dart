import 'dart:io';

import 'package:bull_ui/app_theme.dart';
import 'package:receive/receive.dart';
import 'package:receive/setup.dart' show ReceiveLocalizations;
import 'package:settings/testing.dart';
import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('requires the explicit OK action', (tester) async {
    bool? accepted;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: const [
          ReceiveLocalizations.delegate,
          ...settingsTestLocalizationsDelegates,
        ],
        supportedLocales: SettingsLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              accepted = await PayjoinDisclaimerDialog.show(context);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Payjoin disclaimer'), findsOneWidget);

    await tester.tapAt(const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(find.text('Payjoin disclaimer'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Payjoin disclaimer'), findsOneWidget);
    expect(accepted, isNull);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(accepted, isTrue);
  });

  setUpAll(() async {
    await (FontLoader('Golos Text')..addFont(
          Future.value(
            ByteData.sublistView(
              await File('../../assets/fonts/GolosText.ttf').readAsBytes(),
            ),
          ),
        ))
        .load();
  });

  testWidgets('Payjoin disclaimer can be read and accepted on the S10e', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    // System bar insets in physical pixels, from the S10e capture.
    tester.view.padding = const FakeViewPadding(top: 117, bottom: 144);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    bool? accepted;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.dark),
        locale: const Locale('en'),
        localizationsDelegates: const [
          ReceiveLocalizations.delegate,
          ...settingsTestLocalizationsDelegates,
        ],
        supportedLocales: SettingsLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(1.1)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                accepted = await PayjoinDisclaimerDialog.show(context);
              },
              child: const Text('Open disclaimer'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open disclaimer'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Payjoin disclaimer').hitTestable(), findsOneWidget);
    final ok = find.text('OK');
    await tester.ensureVisible(ok);
    await tester.pumpAndSettle();
    expect(ok.hitTestable(), findsOneWidget);
    await tester.tap(ok);
    await tester.pumpAndSettle();

    expect(accepted, isTrue);
    expect(find.text('Payjoin disclaimer'), findsNothing);
  });
}
