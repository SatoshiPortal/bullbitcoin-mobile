import 'dart:ui' show SemanticsAction, Tristate;

import 'package:bull_ui/bull_ui.dart' show BullPickerChip, BullSwitch;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart' show RegtestHostProfile;
import 'package:settings/settings.dart' show SettingsLocalizations;
import 'package:wizard/src/domain/entity/wizard_choices.dart';
import 'package:wizard/src/ui/screens/wizard_screen.dart';

import 'test_branding.dart';
import 'wizard_test_support.dart';

final _privacySwitch = find.descendant(
  of: find.ancestor(
    of: find.text('Screen Privacy'),
    matching: find.byType(ListTile),
  ),
  matching: find.byType(BullSwitch),
);

SemanticsFinder _semanticsId(String id) =>
    find.semantics.byPredicate((node) => node.identifier == id);

Future<FakeWizardRepository> _pump(
  WidgetTester tester, {
  bool allowDeveloperNetwork = true,
  bool backgroundTasksAvailable = false,
}) async {
  final repository = FakeWizardRepository();
  await pumpWizard(
    tester,
    BlocProvider(
      create: (_) => buildWizardBloc(repository, FakePermissions()),
      child: WizardScreen(
        branding: testBranding,
        exchangeAllowed: false,
        backgroundTasksAvailable: backgroundTasksAvailable,
        allowDeveloperNetwork: allowDeveloperNetwork,
      ),
    ),
  );
  return repository;
}

Future<void> _goToCustomize(WidgetTester tester) async {
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();
}

/// Where the staged choices end up once the wizard is completed.
Future<WizardChoices?> _finish(
  WidgetTester tester,
  FakeWizardRepository repository,
) async {
  await tester.tap(find.text('Skip'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('No'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Get started'));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 4));
  return repository.pending;
}

void main() {
  testWidgets('seven logo taps confirm unlock and reveal the settings', (
    tester,
  ) async {
    await _pump(tester, backgroundTasksAvailable: true);
    final logo = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.identifier == 'wizard.superuser.unlock',
    );
    for (var i = 0; i < 7; i++) {
      await tester.tap(logo);
      await tester.pump(const Duration(milliseconds: 200));
    }
    final context = tester.element(find.byType(WizardScreen));
    final message = SettingsLocalizations.of(context)
        .settingsSuperuserModeUnlockedMessage;
    expect(find.text(message), findsOneWidget);
    await _goToCustomize(tester);
    expect(find.text('Screen Privacy'), findsOneWidget);
    expect(find.text('Network'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('the rows are hidden until seven taps unlock them', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);
    expect(find.text('Advanced Options'), findsNothing);
    await _goToCustomize(tester);
    expect(find.text('Screen Privacy'), findsNothing);
    expect(find.text('Network'), findsNothing);
    expect(_semanticsId('wizard.screen_privacy'), findsNothing);
    expect(_semanticsId('wizard.network.selector'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await unlockSuperuser(tester);
    // No separate page or link: the rows are on the settings step.
    expect(find.text('Advanced Options'), findsNothing);
    await _goToCustomize(tester);
    expect(find.text('Screen Privacy'), findsOneWidget);
    expect(find.text('Network'), findsOneWidget);
    expect(_semanticsId('wizard.screen_privacy'), findsOne);
    expect(_semanticsId('wizard.network.selector'), findsOne);
    semantics.dispose();
  });

  testWidgets('the screen privacy switch is on and stages its change', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final repository = await _pump(tester);
    await unlockSuperuser(tester);
    await _goToCustomize(tester);
    final privacy = _semanticsId('wizard.screen_privacy');
    expect(privacy, findsOne);
    // The row is one merged node: the title and the switch state together.
    final row = tester.getSemantics(_privacySwitch).getSemanticsData();
    expect(row.identifier, 'wizard.screen_privacy');
    expect(row.label, 'Screen Privacy');
    expect(row.hasAction(SemanticsAction.tap), isTrue);
    expect(row.flagsCollection.isToggled, Tristate.isTrue);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await tester.tap(_privacySwitch);
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(_privacySwitch)
          .getSemanticsData()
          .flagsCollection
          .isToggled,
      Tristate.isFalse,
    );

    final staged = await _finish(tester, repository);
    expect(staged?.screenPrivacy, isFalse);
    expect(staged?.touched, contains(WizardField.screenPrivacy));
    semantics.dispose();
  });

  testWidgets('a network pick needs the consent and stays after it', (
    tester,
  ) async {
    final repository = await _pump(tester);
    await unlockSuperuser(tester);
    await _goToCustomize(tester);
    final chip = find.byType(BullPickerChip<Environment>);
    expect(chip, findsOneWidget);

    await tester.tap(find.text('Mainnet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Testnet'));
    await tester.pumpAndSettle();
    final loc = SettingsLocalizations.of(tester.element(chip));
    expect(find.text(loc.settingsDevModeWarningTitle), findsOneWidget);
    // Cancelling keeps mainnet.
    await tester.tap(
      find.text(
        MaterialLocalizations.of(tester.element(chip)).cancelButtonLabel,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mainnet'), findsOneWidget);
    expect(find.text('Testnet'), findsNothing);

    await tester.tap(find.text('Mainnet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Testnet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(loc.settingsDevModeUnderstandButton));
    await tester.pumpAndSettle();
    expect(find.text('Testnet'), findsOneWidget);

    // Going back to mainnet needs no new consent.
    await tester.tap(find.text('Testnet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mainnet'));
    await tester.pumpAndSettle();
    expect(find.text(loc.settingsDevModeWarningTitle), findsNothing);
    await tester.tap(find.text('Mainnet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Testnet'));
    await tester.pumpAndSettle();
    expect(find.text(loc.settingsDevModeWarningTitle), findsNothing);

    final staged = await _finish(tester, repository);
    expect(staged?.network, Environment.testnet);
    expect(staged?.touched, contains(WizardField.network));
  });

  testWidgets('the regtest item follows the configured host profile', (
    tester,
  ) async {
    await _pump(tester);
    await unlockSuperuser(tester);
    await _goToCustomize(tester);
    await tester.tap(find.text('Mainnet'));
    await tester.pumpAndSettle();
    expect(find.text('Testnet'), findsOneWidget);
    expect(
      find.text('Regtest'),
      RegtestHostProfile.isConfigured ? findsOneWidget : findsNothing,
    );
  });

  testWidgets('the network row is hidden where developer networks are off', (
    tester,
  ) async {
    await _pump(tester, allowDeveloperNetwork: false);
    await unlockSuperuser(tester);
    await _goToCustomize(tester);
    expect(find.text('Screen Privacy'), findsOneWidget);
    expect(find.text('Network'), findsNothing);
    expect(find.byType(BullPickerChip<Environment>), findsNothing);
  });

  testWidgets('seven more taps lock again and reset the choices', (
    tester,
  ) async {
    final repository = await _pump(tester);
    await unlockSuperuser(tester);
    await _goToCustomize(tester);
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
    await tester.tap(find.text('Testnet'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(
        SettingsLocalizations.of(tester.element(find.text('Network')))
            .settingsDevModeUnderstandButton,
      ),
    );
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await unlockSuperuser(tester);
    await _goToCustomize(tester);
    expect(find.text('Screen Privacy'), findsNothing);
    expect(find.text('Network'), findsNothing);

    final staged = await _finish(tester, repository);
    expect(staged?.network, isNull);
    expect(staged?.touched, isNot(contains(WizardField.network)));
    expect(staged?.screenPrivacy, isTrue);
    expect(staged?.touched, isNot(contains(WizardField.screenPrivacy)));
  });
}
