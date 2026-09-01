import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/wallet_backup_file_actions.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows all three manual actions and exports encrypted directly', (
    tester,
  ) async {
    WalletBackupFileProtection? selected;
    bool? confirmed;
    await _pump(
      tester,
      onExport: (protection, confirmation) async {
        selected = protection;
        confirmed = confirmation;
      },
    );

    expect(find.text('Export encrypted'), findsOneWidget);
    expect(find.text('Export unencrypted'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
    await tester.tap(find.text('Export encrypted'));
    await tester.pumpAndSettle();

    expect(selected, WalletBackupFileProtection.encrypted);
    expect(confirmed, isFalse);
  });

  testWidgets('plaintext warning cannot be bypassed', (tester) async {
    var exports = 0;
    await _pump(tester, onExport: (_, _) async => exports++);

    await tester.tap(find.text('Export unencrypted'));
    await tester.pumpAndSettle();
    expect(find.text('Export unencrypted wallet data?'), findsOneWidget);
    expect(
      find.textContaining('no seed phrase or private key'),
      findsOneWidget,
    );
    expect(exports, 0);

    await tester.tap(find.text('Export anyway'));
    await tester.pumpAndSettle();
    expect(exports, 1);
  });

  testWidgets('explains comparison and additive recovery before file choice', (
    tester,
  ) async {
    var imports = 0;
    await _pump(tester, onImport: () async => imports++);

    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    expect(find.textContaining('never deletes local wallets'), findsOneWidget);
    expect(find.textContaining('automatic Bull backup is on'), findsOneWidget);
    expect(imports, 0);

    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();
    expect(imports, 1);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  Future<void> Function(WalletBackupFileProtection, bool)? onExport,
  Future<void> Function()? onImport,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: WalletBackupFileActions(
          busy: false,
          onExport: onExport ?? (_, _) async {},
          onImport: onImport ?? () async {},
        ),
      ),
    ),
  );
  await tester.pump();
}
