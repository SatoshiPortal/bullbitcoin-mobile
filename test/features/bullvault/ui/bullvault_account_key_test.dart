import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core/widgets/qr_display_widget.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_account_key.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'public key copy and QR carry recorded origin; missing origin is never guessed',
    (tester) async {
      for (final path in ["m/48h/0h/1h/2h", 'm', null]) {
        final key = WalletDescriptorKey(
          id: 'key',
          signerId: 'signer',
          masterFingerprint: 'DEADBEEF',
          xpubFingerprint: 'cafebabe',
          xpub: 'public-account-key',
          derivationPath: path,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: BullVaultAccountKey(accountKey: key)),
          ),
        );
        final expected = path == null
            ? 'public-account-key'
            : path == 'm'
            ? '[deadbeef]public-account-key'
            : '[deadbeef/48h/0h/1h/2h]public-account-key';
        expect(
          tester.widget<CopyInput>(find.byType(CopyInput)).clipboardText,
          expected,
        );
        await tester.tap(find.byIcon(Icons.qr_code));
        await tester.pumpAndSettle();
        expect(
          tester.widget<QrDisplayWidget>(find.byType(QrDisplayWidget)).data,
          expected,
        );
        final dialogCopy = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(CopyInput),
        );
        expect(dialogCopy, findsOneWidget);
        expect(tester.widget<CopyInput>(dialogCopy).text, expected);
        Navigator.of(tester.element(find.byType(QrDisplayWidget))).pop();
        await tester.pumpAndSettle();
      }
    },
  );
}
