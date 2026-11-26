import 'dart:io';

import 'package:bull_reporting/statistics.dart';
import 'package:bull_ui/bull_ui.dart' show BullSwitch;
import 'package:wizard/src/ui/screens/wizard_screen.dart';
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
      await Statistics.instance.setEnabled(false);
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

    final statistics = find.byType(BullSwitch);
    expect(tester.widget<BullSwitch>(statistics).value, isFalse);
    await tester.ensureVisible(statistics);
    await tester.pumpAndSettle();
    await _toggle(tester, statistics, true);
    expect(tester.widget<BullSwitch>(statistics).value, isTrue);
    // Statistics sits above the error-report question and its buttons.
    expect(
      tester.getTopLeft(statistics).dy <
          tester.getTopLeft(find.text(_reportQuestion)).dy,
      isTrue,
    );

    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    // Staged only on completion, never as a side effect of the answer.
    expect(repository.pending?.reportingConsent, isNull);
    // Before completion, return to the mission page: the answer did not touch the statistics
    // choice. The finder must resolve, so this can never pass vacuously.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(statistics, findsOneWidget);
    expect(tester.widget<BullSwitch>(statistics).value, isTrue);
    expect(repository.pending?.reportingConsent, isNull);

    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pump();
    await tester.pump();
    expect(repository.pending?.reportingConsent, isFalse);
    final marker = File('${directory.path}/statistics_consent.v1');
    expect(
      await tester.runAsync(marker.readAsString),
      'statistics-consent-v1\n',
    );
    expect(Statistics.instance.enabled, isTrue);

    // Reset the process-wide capability after checking the completed state.
    expect(
      await tester.runAsync(() => Statistics.instance.setEnabled(false)),
      isTrue,
    );
    expect(Statistics.instance.enabled, isFalse);
    expect(await tester.runAsync(marker.exists), isFalse);
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
    final tile = tester.widget<BullSwitch>(switchTile);
    if (tile.value == on && tile.onChanged != null) return;
  }
  fail('The statistics switch never settled on $on');
}

const _reportQuestion =
    'Do you accept to be part of our automated issue reporting program?';
