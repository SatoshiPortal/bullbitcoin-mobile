import 'dart:io';

import 'package:wizard/src/ui/screens/wizard_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_branding.dart';

import 'wizard_test_support.dart';

void main() {
  testWidgets('statistics on and declining error reports stay independent', (
    tester,
  ) async {
    final directory = await tester.runAsync(
      () => Directory.systemTemp.createTemp('wizard-statistics-'),
    );
    if (directory == null) fail('Could not create test directory');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => directory.path,
    );
    addTearDown(() async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
      await directory.delete(recursive: true);
    });
    final repository = FakeWizardRepository();
    await pumpWizard(
      tester,
      BlocProvider(
        create: (_) => buildWizardBloc(repository, FakePermissions()),
        child: WizardScreen(
          branding: testBranding,
          exchangeAllowed: false,
          backgroundTasksAvailable: false,
        ),
      ),
    );
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    final statistics = find.byType(SwitchListTile);
    expect(tester.widget<SwitchListTile>(statistics).value, isFalse);
    await tester.ensureVisible(statistics);
    await tester.pumpAndSettle();
    await _toggle(tester, statistics, true);
    expect(tester.widget<SwitchListTile>(statistics).value, isTrue);
    // Statistics sits above the error-report question and its buttons.
    expect(
      tester.getTopLeft(statistics).dy <
          tester.getTopLeft(find.text(_reportQuestion)).dy,
      isTrue,
    );

    await tester.tap(find.text("Don't send error reports"));
    await tester.pumpAndSettle();
    // Staged only on completion, never as a side effect of the answer.
    expect(repository.pending?.reportingConsent, isNull);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(repository.pending?.reportingConsent, isFalse);

    // Back to the mission page: the answer did not touch the statistics
    // choice. The finder must resolve, so this can never pass vacuously.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(statistics, findsOneWidget);
    expect(tester.widget<SwitchListTile>(statistics).value, isTrue);
    expect(repository.pending?.reportingConsent, isFalse);

    // Leave the process-wide singleton off for any later test.
    await _toggle(tester, statistics, false);
    expect(tester.widget<SwitchListTile>(statistics).value, isFalse);
    await tester.pump(const Duration(seconds: 3));
  });
}

/// Taps the statistics switch and waits for its real file write: the marker IO
/// only advances when real time passes and fake async is pumped in turn.
Future<void> _toggle(WidgetTester tester, Finder switchTile, bool on) async {
  await tester.ensureVisible(switchTile);
  await tester.pumpAndSettle();
  await tester.tap(switchTile);
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    final tile = tester.widget<SwitchListTile>(switchTile);
    if (tile.value == on && tile.onChanged != null) return;
  }
  fail('The statistics switch never settled on $on');
}

const _reportQuestion =
    'Do you accept to be part of our automated issue reporting program?';
