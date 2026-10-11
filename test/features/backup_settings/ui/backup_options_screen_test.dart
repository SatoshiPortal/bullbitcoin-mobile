import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/backup_options_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('test options match available backups and disclose Tor', (
    tester,
  ) async {
    final loc = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const BackupOptionsScreen(
          flow: BackupSettingsFlow.test,
          hasPhysicalBackup: false,
          hasEncryptedBackup: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(loc.backupWalletEncryptedVaultTitle), findsOneWidget);
    expect(find.text(loc.backupWalletPhysicalBackupTitle), findsNothing);
    expect(find.text('Uses Tor'), findsOneWidget);
  });
}
