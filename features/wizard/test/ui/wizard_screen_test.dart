import 'dart:ui' show Tristate;

import 'package:wizard/src/domain/entity/wizard_choices.dart';
import 'package:wizard/src/ui/screens/wizard_screen.dart';
import 'package:wizard/src/ui/widgets/customize_step.dart';
import 'package:wizard/src/ui/widgets/mission_consent_row.dart';
import 'package:bull_exchange/bull_exchange.dart' show WizardExchangeOption;
import 'package:bull_ui/bull_ui.dart' show BullSwitch;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_branding.dart';
import 'wizard_test_support.dart';

void main() {
  for (final allowed in [false, true]) {
    testWidgets(
      'the exchange switch follows the platform permission $allowed',
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
        // Dark mode, then the exchange where the platform allows it.
        expect(switches, findsNWidgets(allowed ? 2 : 1));
        expect(
          find.byType(WizardExchangeOption),
          allowed ? findsOneWidget : findsNothing,
        );
        if (allowed) {
          await tester.tap(switches.at(1));
          await tester.pump();
        }

        // Skip on the settings page confirms the exchange choice shown there,
        // then sends the user to the mandatory mission question.
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();
        expect(find.byType(MissionConsentRow), findsOneWidget);
        await tester.tap(find.text("Don't send error reports"));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Get started'));
        await tester.pumpAndSettle();

        final saved = repository.pending;
        expect(saved, isNotNull);
        expect(saved?.reportingConsent, isFalse);
        expect(saved?.touched.contains(WizardField.exchangeAccess), allowed);
        if (allowed) expect(saved?.exchangeAccess, isFalse);
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
      'BULL Exchange',
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
    await tester.tap(find.text("Don't send error reports"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
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
          final label = answer
              ? 'Send error reports'
              : "Don't send error reports";
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
        await tester.tap(find.text('Send error reports'));
        await tester.tap(find.text("Don't send error reports"));
        expect(yesTaps, 1);
        expect(noTaps, 1);
      } finally {
        semantics.dispose();
      }
    });
  }

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
      final yesX = tester.getCenter(find.text('Send error reports')).dx;
      final noX = tester.getCenter(find.text("Don't send error reports")).dx;
      expect(yesX < noX, yesFirst);
    });
  }
}
