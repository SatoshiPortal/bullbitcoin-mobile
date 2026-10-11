import 'dart:io' show Platform;

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/tab_menu_vertical_button.dart';
import 'package:bb_mobile/features/import_wallet/import_wallet_page.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'hardware import retains watch-only and every device without seed import',
    (tester) async {
      final loc = AppLocalizationsEn();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ImportWalletPage(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<TabMenuVerticalButton>(
              find.byType(TabMenuVerticalButton),
            )
            .map((button) => button.title),
        [
          loc.importWalletImportWatchOnly,
          loc.importWalletColdcardQ,
          loc.importWalletColdcardMk4,
          loc.importWalletSeedSigner,
          loc.importWalletSpecter,
          loc.importWalletKrux,
          loc.importWalletJade,
          loc.importWalletPassport,
          loc.importWalletKeystone,
          loc.importWalletLedger,
          Platform.isAndroid
              ? loc.importWalletBitBox
              : loc.importWalletBitBoxNova,
        ],
      );
      expect(find.text('Hardware wallet'), findsOneWidget);
    },
  );
}
