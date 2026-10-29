import 'package:bb_mobile/features/wallet_sync/domain/usecases/start_wallet_sync_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/domain/usecases/watch_wallet_sync_status_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/domain/wallet_sync_status.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_status_usecase.dart';
import 'package:bb_mobile/core/widgets/mnemonic_widget.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/check_duplicate_mnemonic_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/discover_mnemonic_wallets_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_wallet_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/cubit.dart';
import 'package:bb_mobile/features/import_mnemonic/router.dart';
import 'package:bb_mobile/features/import_mnemonic/ui/select_purpose_page.dart';
import 'package:bb_mobile/features/wallet_sync/domain/usecases/get_wallet_sync_network_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/domain/usecases/load_wallet_sync_settings_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/domain/usecases/save_wallet_sync_settings_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/public/wallet_sync_facade.dart';
import 'package:bb_mobile/features/wallet_sync/ui/wallet_sync_options_sheet.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork;

class _CheckDuplicate extends Mock implements CheckDuplicateMnemonicUsecase {}

class _CheckStatus extends Mock implements CheckWalletStatusUsecase {}

class _Import extends Mock implements ImportWalletUsecase {}

class _Network extends Mock implements GetWalletSyncNetworkUsecase {}

class _Load extends Fake implements LoadWalletSyncSettingsUsecase {}

class _Save extends Fake implements SaveWalletSyncSettingsUsecase {}

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'mnemonic private flow imports only after birthday and never previews Electrum',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.flutterplaza.no_screenshot_methods'),
            (_) async => true,
          );
      final checkDuplicate = _CheckDuplicate();
      final checkStatus = _CheckStatus();
      final import = _Import();
      final network = _Network();
      when(
        () => network.execute(),
      ).thenAnswer((_) async => const Ok(BitcoinNetwork.mainnet));
      when(
        () => checkDuplicate.execute(
          mnemonicWords: any(named: 'mnemonicWords'),
          passphrase: '',
        ),
      ).thenAnswer((_) async => const Ok(null));
      when(
        () => import.execute(
          mnemonicWords: any(named: 'mnemonicWords'),
          label: 'Public BIP39 fixture',
          bitcoinSyncSource: BitcoinSyncSource.compactBlockFilters,
        ),
      ).thenAnswer((_) async => const Err(ImportMnemonicUnexpectedFailure()));
      await locator.reset();
      addTearDown(locator.reset);
      locator.registerFactory<ImportMnemonicCubit>(
        () => ImportMnemonicCubit(
          importWalletUsecase: import,
          discovery: DiscoverMnemonicWalletsUsecase(check: checkStatus),
          checkDuplicateMnemonicUsecase: checkDuplicate,
        ),
      );
      locator.registerSingleton<WalletSyncFacade>(
        WalletSyncFacade(
          watch: _WatchSync(),
          start: _StartSync(),
          network: network,
          load: _Load(),
          save: _Save(),
        ),
      );
      final router = GoRouter(
        initialLocation: ImportMnemonicRoute.importMnemonicHome.path,
        routes: [ImportMnemonicRouter.route],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();
      final publicFixture = bip39.Mnemonic(
        List.filled(16, 0),
        bip39.Language.english,
      );
      for (final label in ['', '   ']) {
        tester.widget<MnemonicWidget>(find.byType(MnemonicWidget)).onSubmit((
          words: publicFixture.words,
          passphrase: '',
          label: label,
          language: bip39.Language.english,
        ));
        await tester.pumpAndSettle();
        expect(find.byType(WalletSyncOptionsSheet), findsNothing);
        final context = tester.element(find.byType(MnemonicWidget));
        expect(
          find.text(AppLocalizations.of(context).importMnemonicEmptyLabelError),
          findsOneWidget,
        );
        verifyZeroInteractions(checkDuplicate);
        verifyZeroInteractions(checkStatus);
        verifyZeroInteractions(import);
      }
      tester.widget<MnemonicWidget>(find.byType(MnemonicWidget)).onSubmit((
        words: publicFixture.words,
        passphrase: '',
        label: 'Public BIP39 fixture',
        language: bip39.Language.english,
      ));
      await tester.pumpAndSettle();
      expect(find.byType(WalletSyncOptionsSheet), findsOneWidget);
      verifyZeroInteractions(checkStatus);
      verifyZeroInteractions(import);
      await _tap(tester, 'Private peer-to-peer sync');
      await _tap(tester, 'Continue');
      expect(find.text('bc1q…'), findsOneWidget);
      verifyZeroInteractions(checkStatus);
      await _tap(tester, 'Continue');
      expect(find.byType(WalletBirthdayForm), findsOneWidget);
      verifyZeroInteractions(import);
      await _tap(tester, 'I don’t know');
      verifyZeroInteractions(import);
      await _tap(tester, 'Scan from August 2017');
      verify(
        () => import.execute(
          mnemonicWords: any(named: 'mnemonicWords'),
          label: 'Public BIP39 fixture',
          bitcoinSyncSource: BitcoinSyncSource.compactBlockFilters,
        ),
      ).called(1);
      verifyZeroInteractions(checkStatus);
      expect(find.byType(SelectScriptTypePage), findsNothing);
    },
  );
}

class _StartSync extends Fake implements StartWalletSyncUsecase {
  @override
  void execute(String walletId, {bool policyChanged = false}) {}
}

class _WatchSync extends Fake implements WatchWalletSyncStatusUsecase {
  @override
  Stream<WalletSyncStatus> execute(String walletId) => Stream.value(
    const WalletSyncStatus(
      source: BitcoinSyncSource.electrum,
      recoveryRequired: false,
    ),
  );
}
