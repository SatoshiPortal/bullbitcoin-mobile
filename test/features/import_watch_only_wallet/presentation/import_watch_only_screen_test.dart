import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_descriptor_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_xpub_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/parse_watch_only_input_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/import_watch_only_screen.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Settings extends Mock implements SettingsRepository {}

class _Xpub extends Mock implements ImportWatchOnlyXpubUsecase {}

class _Descriptor extends Mock implements ImportWatchOnlyDescriptorUsecase {}

void main() {
  for (final labelCorrection in [false, true]) {
    testWidgets(
      'label edit preserves only valid errors, correction=$labelCorrection',
      (tester) async {
        // Published BIP84 test account, as entered in the FIX device campaign.
        const vpub =
            'vpub5Y6cjg78GGuNLsaPhmYsiw4gYX3HoQiRBiSwDaBXKUafCt9bNwWQiitDk5VZ5BVxYnQdwoTyXSs2JHRPAgjAvtbBrf8ZhDYe2jWAqvZVnsc';
        final wallet = (await WatchOnlyWalletEntity.parse(
          vpub,
        )).copyWith(label: labelCorrection ? '' : 'NeverScanned');
        final settings = _Settings();
        final importer = _Xpub();
        when(settings.fetch).thenAnswer(
          (_) async => SettingsEntity(
            environment: labelCorrection
                ? Environment.testnet
                : Environment.regtest,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'USD',
          ),
        );
        locator.registerSingleton<SettingsRepository>(settings);
        locator.registerSingleton<ImportWatchOnlyXpubUsecase>(importer);
        locator.registerSingleton<ImportWatchOnlyDescriptorUsecase>(
          _Descriptor(),
        );
        locator.registerSingleton<ParseWatchOnlyInputUsecase>(
          ParseWatchOnlyInputUsecase(),
        );
        addTearDown(locator.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ImportWatchOnlyScreen(watchOnlyWallet: wallet),
          ),
        );
        for (var attempt = 0; attempt < 2; attempt++) {
          final button = find.text(AppLocalizationsEn().importWatchOnlyImport);
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byType(TextField).last,
            labelCorrection ? 'Corrected label' : 'Renamed wallet',
          );
          await tester.pumpAndSettle();
          await tester.pump(const Duration(seconds: 8));
          await tester.pumpAndSettle();
          expect(
            find.text(
              labelCorrection
                  ? AppLocalizationsEn().importWatchOnlyErrorLabelRequired
                  : AppLocalizationsEn().importWatchOnlyErrorNetworkMismatch,
            ),
            labelCorrection ? findsNothing : findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          if (labelCorrection) break;
        }
        verifyZeroInteractions(importer);
      },
    );
  }
}
