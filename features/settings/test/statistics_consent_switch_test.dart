import 'dart:io';

import 'package:bull_reporting/statistics.dart';
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
      const MaterialApp(
        localizationsDelegates: SettingsLocalizations.localizationsDelegates,
        supportedLocales: SettingsLocalizations.supportedLocales,
        home: Scaffold(body: StatisticsConsentSwitch()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      true,
    );

    await tester.runAsync(() async {
      await file.delete();
      await Directory(file.path).create();
    });
    await tester.runAsync(() async {
      await tester.tap(find.byType(SwitchListTile));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(Statistics.instance.enabled, isFalse);
    expect(find.textContaining('previous choice may return'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.runAsync(() => Directory(file.path).delete());
    await tester.runAsync(() async {
      await tester.tap(find.text('Retry'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsNothing);
    expect(Statistics.instance.enabled, isFalse);
  });
}
