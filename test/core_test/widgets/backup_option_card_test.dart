import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/cards/backup_option_card.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/backup_options_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('wraps multiple backup labels on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        home: Scaffold(
          body: BackupOptionCard(
            icon: const Icon(Icons.lock),
            title: 'Encrypted vault',
            description: 'Encrypted recovery stored in a location you choose.',
            tags: const ['Easy', 'Uses Tor'],
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Easy'), findsOneWidget);
    expect(find.text('Uses Tor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet recovery choices keep the PR2453 posture copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const BackupOptionsScreen(flow: BackupSettingsFlow.backup),
      ),
    );
    await tester.pump();

    expect(find.text('Encrypted vault'), findsOneWidget);
    expect(find.text('Physical backup'), findsOneWidget);
    expect(find.text('Easy and simple (1 minute)'), findsOneWidget);
    expect(find.text('Uses Tor'), findsOneWidget);
    expect(find.text('Automatic Bull backup'), findsNothing);

    final semantics = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.text('How to decide?')),
      matchesSemantics(
        label: 'How to decide?',
        isButton: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('test flow only offers backups already tested end to end', (
    tester,
  ) async {
    Future<void> pump({required bool physical, required bool encrypted}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: BackupOptionsScreen(
            flow: BackupSettingsFlow.test,
            hasPhysicalBackup: physical,
            hasEncryptedBackup: encrypted,
          ),
        ),
      );
      await tester.pump();
    }

    await pump(physical: true, encrypted: false);
    expect(find.text('Physical backup'), findsOneWidget);
    expect(find.text('Encrypted vault'), findsNothing);

    await pump(physical: false, encrypted: true);
    expect(find.text('Physical backup'), findsNothing);
    expect(find.text('Encrypted vault'), findsOneWidget);

    await pump(physical: true, encrypted: true);
    expect(find.text('Physical backup'), findsOneWidget);
    expect(find.text('Encrypted vault'), findsOneWidget);
  });
}
