import 'dart:ui' show Tristate;

import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullSwitch, bullUiLocalizationsDelegate;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart' show RegtestHostProfile;
import 'package:settings/settings.dart';
import 'package:wizard/src/ui/widgets/wizard_network_control.dart';
import 'package:wizard/generated/l10n/wizard_localizations.dart';

import 'test_branding.dart';

void main() {
  testWidgets('privacy is superuser-only even when network is unavailable', (
    tester,
  ) async {
    bool? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: const [
          SettingsLocalizations.delegate,
          WizardLocalizations.delegate,
          bullUiLocalizationsDelegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: Scaffold(
          body: WizardNetworkControl(
            logo: testBranding.welcomeLogo,
            allowDeveloperNetwork: false,
            onChanged: (_) {},
            onPrivacyChanged: (value) => selected = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final semantics = tester.ensureSemantics();
    expect(find.byType(BullSwitch), findsNothing);
    final logo = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.identifier == 'wizard.superuser.unlock',
    );
    for (var i = 0; i < 7; i++) {
      await tester.tap(logo);
      await tester.pump();
    }
    await tester.tap(find.text('Advanced Options'));
    await tester.pumpAndSettle();
    expect(find.text('Testnet'), findsNothing);
    expect(tester.widget<BullSwitch>(find.byType(BullSwitch)).value, isTrue);
    final privacy = find.semantics.byPredicate(
      (node) => node.identifier == 'wizard.screen_privacy',
    );
    expect(privacy, findsOne);
    expect(
      privacy.evaluate().single.flagsCollection.isToggled,
      Tristate.isTrue,
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    tester.semantics.tap(privacy);
    await tester.pumpAndSettle();
    expect(selected, isFalse);
    expect(
      privacy.evaluate().single.flagsCollection.isToggled,
      Tristate.isFalse,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Advanced Options'));
    await tester.pumpAndSettle();
    expect(tester.widget<BullSwitch>(find.byType(BullSwitch)).value, isFalse);
    await tester.pageBack();
    await tester.pumpAndSettle();
    for (var i = 0; i < 7; i++) {
      await tester.tap(logo);
      await tester.pump();
    }
    expect(selected, isNull);
    semantics.dispose();
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('advanced options scroll at large text scale', (tester) async {
    tester.view.physicalSize = const Size(360, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: const [
          SettingsLocalizations.delegate,
          WizardLocalizations.delegate,
          bullUiLocalizationsDelegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: Scaffold(
          body: WizardNetworkControl(
            logo: testBranding.welcomeLogo,
            onChanged: (_) {},
            onPrivacyChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final logo = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.identifier == 'wizard.superuser.unlock',
    );
    for (var i = 0; i < 7; i++) {
      await tester.tap(logo);
      await tester.pump();
    }
    await tester.tap(find.text('Advanced Options'));
    await tester.pumpAndSettle();
    expect(find.byType(SingleChildScrollView), findsWidgets);
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(find.text('Testnet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  if (RegtestHostProfile.isConfigured) {
    testWidgets('a configured regtest choice is selected after consent', (
      tester,
    ) async {
      Environment? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: const [
            SettingsLocalizations.delegate,
            WizardLocalizations.delegate,
            bullUiLocalizationsDelegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Scaffold(
            body: WizardNetworkControl(
              logo: testBranding.welcomeLogo,
              onChanged: (value) => selected = value,
              onPrivacyChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final logo = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.identifier == 'wizard.superuser.unlock',
      );
      for (var i = 0; i < 7; i++) {
        await tester.tap(logo);
        await tester.pump();
      }
      await tester.tap(find.text('Advanced Options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Regtest'));
      await tester.pumpAndSettle();
      final loc = SettingsLocalizations.of(
        tester.element(find.text('Regtest')),
      );
      await tester.tap(find.text(loc.settingsDevModeUnderstandButton));
      await tester.pumpAndSettle();
      expect(selected, Environment.regtest);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });
  }
  testWidgets('seven taps reveal the selector and selection requires consent', (
    tester,
  ) async {
    Environment? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: const [
          SettingsLocalizations.delegate,
          WizardLocalizations.delegate,
          bullUiLocalizationsDelegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: Scaffold(
          body: WizardNetworkControl(
            logo: testBranding.welcomeLogo,
            onChanged: (value) => selected = value,
            onPrivacyChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final semantics = tester.ensureSemantics();
    final logo = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.identifier == 'wizard.superuser.unlock',
    );
    final selector = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.identifier == 'wizard.network.selector',
    );
    final advanced = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.identifier == 'wizard.advanced_options',
    );
    expect(logo, findsOneWidget);
    expect(advanced, findsNothing);
    expect(
      find.semantics.byPredicate(
        (node) => node.identifier == 'wizard.advanced_options',
      ),
      findsNothing,
    );
    expect(selector, findsNothing);
    expect(
      find.semantics.byPredicate(
        (node) => node.identifier == 'wizard.network.selector',
      ),
      findsNothing,
    );
    final logoNode = find.semantics.byPredicate(
      (node) => node.identifier == 'wizard.superuser.unlock',
    );
    for (var i = 0; i < 7; i++) {
      tester.semantics.tap(logoNode);
      await tester.pump();
    }
    expect(advanced, findsOneWidget);
    expect(
      find.semantics.byPredicate(
        (node) => node.identifier == 'wizard.advanced_options',
      ),
      findsOne,
    );
    expect(selector, findsNothing);
    tester.semantics.tap(
      find.semantics.byPredicate(
        (node) => node.identifier == 'wizard.advanced_options',
      ),
    );
    await tester.pumpAndSettle();
    expect(selector, findsOneWidget);
    expect(
      find.semantics.byPredicate(
        (node) => node.identifier == 'wizard.network.selector',
      ),
      findsOne,
    );
    expect(
      find.text('Regtest'),
      RegtestHostProfile.isConfigured ? findsOneWidget : findsNothing,
    );
    tester.semantics.tap(
      find.semantics.byPredicate(
        (node) => node.identifier == 'wizard.network.testnet',
      ),
    );
    await tester.pumpAndSettle();
    expect(selected, isNull);
    final loc = SettingsLocalizations.of(tester.element(selector));
    await tester.tap(
      find.text(
        MaterialLocalizations.of(tester.element(selector)).cancelButtonLabel,
      ),
    );
    await tester.pumpAndSettle();
    expect(selected, isNull);
    await tester.tap(find.text('Testnet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(loc.settingsDevModeUnderstandButton));
    await tester.pumpAndSettle();
    expect(selected, Environment.testnet);
    expect(
      find.semantics
          .byPredicate((node) => node.identifier == 'wizard.network.testnet')
          .evaluate()
          .single
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(selector, findsNothing);
    expect(advanced, findsOneWidget);
    await tester.tap(find.text('Advanced Options'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Semantics>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics &&
                  widget.properties.identifier == 'wizard.network.testnet',
            ),
          )
          .properties
          .selected,
      isTrue,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    for (var i = 0; i < 7; i++) {
      await tester.tap(logo);
      await tester.pump();
    }
    expect(selector, findsNothing);
    expect(selected, isNull);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    semantics.dispose();
  });
}
