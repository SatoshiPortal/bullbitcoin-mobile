import 'dart:io';

import 'package:bull_reporting/statistics.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullSettingsEntryItem, BullSnackBar, BullSwitch;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:settings/settings.dart';

void main() {
  testWidgets('failed withdrawal shows an error and retry persists it', (
    tester,
  ) async {
    final directory = await tester.runAsync(
      () => Directory.systemTemp.createTemp('statistics-widget-'),
    );
    if (directory == null) fail('Could not create test directory');
    addTearDown(() async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
      await directory.delete(recursive: true);
    });
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => directory.path,
    );

    final file = File('${directory.path}/statistics_consent.v1');
    await tester.runAsync(() => file.writeAsString('statistics-consent-v1\n'));
    await tester.runAsync(Statistics.instance.initialize);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: SettingsLocalizations.localizationsDelegates,
        supportedLocales: SettingsLocalizations.supportedLocales,
        home: const Scaffold(
          body: StatisticsConsentSwitch(showRestartNotice: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.byType(BullSettingsEntryItem), findsOneWidget);
    expect(tester.widget<BullSwitch>(find.byType(BullSwitch)).value, true);

    await tester.runAsync(() async {
      await file.delete();
      await Directory(file.path).create();
    });
    await tester.runAsync(() async {
      await tester.tap(find.byType(BullSwitch));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(Statistics.instance.enabled, isFalse);
    expect(find.textContaining('previous choice may return'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    const notice = 'Close and reopen the app to apply this change.';
    expect(find.text(notice), findsNothing);

    await tester.runAsync(() => Directory(file.path).delete());
    await tester.runAsync(() async {
      await tester.tap(find.text('Retry'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsNothing);
    expect(Statistics.instance.enabled, isFalse);
    expect(find.text(notice), findsOneWidget);
    BullSnackBar.dismiss();
    await tester.pumpAndSettle();

    expect(tester.widget<BullSwitch>(find.byType(BullSwitch)).value, isFalse);

    await tester.runAsync(() async {
      final enabled = Statistics.instance.changes.firstWhere((value) => value);
      await tester.tap(find.byType(BullSwitch));
      await enabled.timeout(const Duration(seconds: 3));
    });
    await tester.pumpAndSettle();
    expect(Statistics.instance.failedChoice, isNull);
    expect(await tester.runAsync(file.exists), isTrue);
    expect(Statistics.instance.enabled, isTrue);
    expect(find.text(notice), findsOneWidget);
    BullSnackBar.dismiss();
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.byType(BullSwitch));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(Statistics.instance.enabled, isFalse);
    expect(find.text(notice), findsOneWidget);
    BullSnackBar.dismiss();
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: SettingsLocalizations.localizationsDelegates,
        supportedLocales: SettingsLocalizations.supportedLocales,
        home: const Scaffold(body: StatisticsConsentSwitch()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final enabled = Statistics.instance.changes.firstWhere((value) => value);
      await tester.tap(find.byType(BullSwitch));
      await enabled.timeout(const Duration(seconds: 3));
    });
    await tester.pumpAndSettle();
    expect(Statistics.instance.enabled, isTrue);
    expect(find.text(notice), findsNothing);
  });
}
