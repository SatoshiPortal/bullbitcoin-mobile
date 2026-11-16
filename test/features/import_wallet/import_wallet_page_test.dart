import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';

import 'dart:io' show Platform;

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bb_mobile/features/import_wallet/import_wallet_page.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

class _Settings extends Mock implements SettingsCubit {}

void main() {
  testWidgets(
    'hardware import retains watch-only and every device without seed import',
    (tester) async {
      final loc = AppLocalizationsEn();
      final settings = _Settings();
      when(() => settings.state).thenReturn(
        SettingsState(
          storedSettings: SettingsEntity(
            environment: Environment.mainnet,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'USD',
          ),
        ),
      );
      when(() => settings.stream).thenAnswer((_) => const Stream.empty());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<SettingsCubit>.value(
            value: settings,
            child: const ImportWalletPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<BullTabMenuVerticalButton>(
              find.byType(BullTabMenuVerticalButton),
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
