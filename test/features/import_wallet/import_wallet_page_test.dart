import 'package:bb_mobile/features/import_wallet/import_wallet_page.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps BullVault creation out of wallet import', (tester) async {
    final localization = AppLocalizationsEn();
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ImportWalletPage(),
      ),
    );

    expect(find.text(localization.bullVaultCreateEntry), findsNothing);
    expect(find.text(localization.importWalletImportMnemonic), findsOneWidget);
  });
}
