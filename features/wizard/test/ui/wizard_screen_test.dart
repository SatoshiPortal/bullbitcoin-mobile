import 'dart:ui' show Tristate;

import 'package:wizard/src/domain/entity/wizard_choices.dart';
import 'package:wizard/src/ui/screens/wizard_screen.dart';
import 'package:wizard/src/ui/widgets/customize_step.dart';
import 'package:wizard/src/ui/widgets/mission_consent_row.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullSwitch;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences/preferences.dart' show Environment;
import 'package:settings/settings.dart' show SettingsLocalizations;

import 'test_branding.dart';
import 'wizard_test_support.dart';

void main() {
  testWidgets('wizard stages the confirmed network before completion', (
    tester,
  ) async {
    final repository = FakeWizardRepository();
    await pumpWizard(
      tester,
      BlocProvider(
        create: (_) => buildWizardBloc(repository, FakePermissions()),
        child: WizardScreen(
          branding: testBranding,
          exchangeAllowed: false,
          backgroundTasksAvailable: false,
          allowDeveloperNetwork: true,
        ),
      ),
    );
    await unlockSuperuser(tester);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('Screen Privacy'),
          matching: find.byType(ListTile),
        ),
        matching: find.byType(BullSwitch),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mainnet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Testnet').last);
    await tester.pumpAndSettle();
    final loc = SettingsLocalizations.of(tester.element(find.text('Network')));
    await tester.tap(find.text(loc.settingsDevModeUnderstandButton));
    await tester.pumpAndSettle();
    expect(find.text('Testnet'), findsOneWidget);
    // The rows stay when the user goes on and comes back.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Testnet'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pump();
    await tester.pump();
    expect(repository.pending?.screenPrivacy, isFalse);
    expect(repository.pending?.touched, contains(WizardField.screenPrivacy));
    expect(repository.pending?.network, Environment.testnet);
    expect(repository.pending?.touched, contains(WizardField.network));
    await tester.pump(const Duration(seconds: 4));
  });

  for (final allowed in [false, true]) {
    testWidgets(
      'the exchange default follows the platform permission $allowed',
      (tester) async {
        final repository = FakeWizardRepository();
        await pumpWizard(
          tester,
          BlocProvider(
            create: (_) => buildWizardBloc(repository, FakePermissions()),
            child: WizardScreen(
              branding: testBranding,
              exchangeAllowed: allowed,
              backgroundTasksAvailable: false,
            ),
          ),
        );
        final pages =
            tester.widget<PageView>(find.byType(PageView)).childrenDelegate
                as SliverChildListDelegate;
        expect(pages.children, hasLength(4));

        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        final switches = find.descendant(
          of: find.byType(CustomizeStep),
          matching: find.byType(BullSwitch),
        );
        // Dark mode only: the exchange is managed from the app settings.
        expect(switches, findsOneWidget);
        expect(find.text('BULL Exchange'), findsNothing);

        // Skip sends the user to the mandatory mission question.
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();
        expect(find.byType(MissionConsentRow), findsOneWidget);
        await tester.tap(find.text('No'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Get started'));
        await tester.pump();
        await tester.pump();

        final saved = repository.pending;
        expect(saved, isNotNull);
        expect(saved?.reportingConsent, isFalse);
        // Where the platform allows the exchange, finishing stages its
        // default (on) with no choice offered.
        expect(saved?.touched.contains(WizardField.exchangeAccess), allowed);
        expect(saved?.exchangeAccess, isTrue);
        // Lets the mission-required snackbar time out.
        await tester.pump(const Duration(seconds: 3));
      },
    );
  }

  testWidgets('background tasks lead to notifications on the settings page', (
    tester,
  ) async {
    final repository = FakeWizardRepository();
    final permissions = FakePermissions();
    await pumpWizard(
      tester,
      BlocProvider(
        create: (_) => buildWizardBloc(repository, permissions),
        child: WizardScreen(
          branding: testBranding,
          exchangeAllowed: true,
          backgroundTasksAvailable: true,
        ),
      ),
    );
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    final order = [
      'Language',
      'Default currency',
      'Dark Mode',
      'Background Tasks',
      'Notifications',
    ];
    final tops = [for (final t in order) tester.getTopLeft(find.text(t)).dy];
    for (var i = 1; i < tops.length; i++) {
      expect(tops[i] > tops[i - 1], isTrue, reason: order[i]);
    }

    // The system refuses: the row says so instead of its description.
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('Notifications'),
          matching: find.byType(ListTile),
        ),
        matching: find.byType(BullSwitch),
      ),
    );
    await tester.pumpAndSettle();
    expect(permissions.requests, 1);
    expect(find.text('Blocked in system settings'), findsOneWidget);

    // Notifications only make sense while background tasks run.
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('Background Tasks'),
          matching: find.byType(ListTile),
        ),
        matching: find.byType(BullSwitch),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsNothing);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pump();
    await tester.pump();
    final saved = repository.pending;
    expect(saved?.touched.contains(WizardField.backgroundTasks), isTrue);
    expect(saved?.backgroundTasks, isFalse);
    await tester.pump(const Duration(seconds: 3));
  });

  for (final consent in <bool?>[null, true, false]) {
    testWidgets('consent selection is announced once: $consent', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        var yesTaps = 0;
        var noTaps = 0;
        await pumpWizard(
          tester,
          Scaffold(
            body: MissionConsentRow(
              consent: consent,
              onYes: () => yesTaps++,
              onNo: () => noTaps++,
              yesFirst: true,
            ),
          ),
        );
        for (final answer in [true, false]) {
          final label = answer ? 'Yes' : 'No';
          final nodes = find.semantics.byPredicate(
            (node) => node.label == label && node.flagsCollection.isButton,
          );
          expect(nodes, findsOne);
          final node = nodes.evaluate().single;
          expect(
            node.flagsCollection.isSelected,
            consent == answer ? Tristate.isTrue : Tristate.isFalse,
          );
        }
        await tester.tap(find.text('Yes'));
        await tester.tap(find.text('No'));
        expect(yesTaps, 1);
        expect(noTaps, 1);
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('the answers are plain Yes and No buttons', (tester) async {
    await pumpWizard(
      tester,
      Scaffold(
        body: MissionConsentRow(
          consent: true,
          onYes: () {},
          onNo: () {},
          yesFirst: true,
        ),
      ),
    );
    expect(find.text('Yes'), findsOneWidget);
    expect(find.text('No'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_checked), findsNothing);
    expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
    expect(find.byType(BullButton), findsNWidgets(2));
  });

  for (final yesFirst in [true, false]) {
    testWidgets('the consent row puts Yes on the left: $yesFirst', (
      tester,
    ) async {
      await pumpWizard(
        tester,
        Scaffold(
          body: MissionConsentRow(
            consent: null,
            onYes: () {},
            onNo: () {},
            yesFirst: yesFirst,
          ),
        ),
      );
      final yesX = tester.getCenter(find.text('Yes')).dx;
      final noX = tester.getCenter(find.text('No')).dx;
      expect(yesX < noX, yesFirst);
    });
  }
}
