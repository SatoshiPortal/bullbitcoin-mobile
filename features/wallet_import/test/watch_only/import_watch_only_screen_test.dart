import 'package:wallet_import/src/domain/watch_only/import_watch_only_descriptor_usecase.dart';
import 'package:wallet_import/src/domain/watch_only/import_watch_only_xpub_usecase.dart';
import 'package:wallet_import/src/domain/watch_only/parse_watch_only_input_usecase.dart';
import 'package:wallet_import/src/domain/watch_only/read_watch_only_network_usecase.dart';
import 'package:wallet_import/src/domain/watch_only/watch_only_wallet_entity.dart';
import 'package:wallet_import/src/presentation/watch_only/import_watch_only_cubit.dart';
import 'package:wallet_import/src/ui/watch_only/import_watch_only_screen.dart';
import 'package:primitives/primitives.dart' show Ok;
import 'package:preferences/preferences.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:wallet_import/src/domain/import_failure.dart';
import 'package:wallet_import/wallet_import.dart' show ImportLocalizations;
import 'package:wallet_import/generated/l10n/import_localizations_en.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Settings extends Mock implements ActiveEnvironmentReader {}

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
        final parsed = await ParseWatchOnlyInputUsecase().execute(
          vpub,
          environment: Environment.testnet.networkEnv,
        );
        final wallet = ((parsed as Ok).value as WatchOnlyWalletEntity).copyWith(
          label: labelCorrection ? '' : 'NeverScanned',
        );
        final settings = _Settings();
        final importer = _Xpub();
        when(settings.readActiveEnvironment)
            .thenAnswer((_) async => Ok(Environment.testnet));
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: ImportLocalizations.localizationsDelegates,
            supportedLocales: ImportLocalizations.supportedLocales,
            home: ImportWatchOnlyScreen(
              createCubit: () => ImportWatchOnlyCubit(
                watchOnlyWallet: wallet,
                importWatchOnlyXpubUsecase: importer,
                importWatchOnlyDescriptorUsecase: _Descriptor(),
                parseWatchOnlyInputUsecase: ParseWatchOnlyInputUsecase(),
                readNetworkUsecase: ReadWatchOnlyNetworkUsecase(settings),
              ),
              onImported: (_) => fail('unexpected import'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // The form was captured on testnet; switch the live selection before
        // submission to keep testing a real mismatch after regtest support.
        if (!labelCorrection) {
          when(settings.readActiveEnvironment)
              .thenAnswer((_) async => Ok(Environment.mainnet));
        }
        for (var attempt = 0; attempt < 2; attempt++) {
          final button = find.text(
            ImportLocalizationsEn().importWatchOnlyImport,
          );
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
                  ? ImportLocalizationsEn().importWatchOnlyErrorLabelRequired
                  : ImportLocalizationsEn().importWatchOnlyErrorNetworkMismatch,
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
