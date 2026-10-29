import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/validate_watch_only_import_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/import_watch_only_failure.dart';
import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_descriptor_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_xpub_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/parse_watch_only_input_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/cubit/import_watch_only_cubit.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/watch_only_details_widget.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:bb_mobile/features/wallet_sync/public/wallet_sync_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_ui/bull_ui.dart' show BullText, BullTheme;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork;
import 'package:satoshifier/satoshifier.dart' as satoshifier;

class _Settings extends Mock implements SettingsRepository {}

class _ImportDescriptor extends Mock
    implements ImportWatchOnlyDescriptorUsecase {}

class _ImportXpub extends Mock implements ImportWatchOnlyXpubUsecase {}

class _Parse extends Mock implements ParseWatchOnlyInputUsecase {}

class _Descriptor extends Mock implements satoshifier.Descriptor {}

class _WatchDescriptor extends Mock
    implements satoshifier.WatchOnlyDescriptor {}

class _Extended extends Mock implements satoshifier.ExtendedPubkey {}

class _WatchXpub extends Mock implements satoshifier.WatchOnlyXpub {}

class _Choices extends Fake implements WalletSyncFacade {
  int calls = 0;
  WalletSyncSelection? lastInitial;
  @override
  Future<WalletSyncSelection?> choose(
    BuildContext context, {
    BitcoinNetwork? network,
    bool askScriptType = false,
    WalletSyncSelection initial = const WalletSyncSelection(),
    bool changingSource = false,
  }) async {
    calls++;
    lastInitial = initial;
    return null;
  }
}

WatchOnlyWalletEntity _wallet(bool descriptor, String label) {
  if (descriptor) {
    final key = _Descriptor();
    when(() => key.network).thenReturn(satoshifier.Network.bitcoinMainnet);
    when(() => key.combined).thenReturn('wpkh(public-fixture)');
    when(() => key.derivation).thenReturn(satoshifier.Derivation.bip84);
    final watch = _WatchDescriptor();
    when(() => watch.descriptor).thenReturn(key);
    return WatchOnlyWalletEntity.descriptor(
      watchOnlyDescriptor: watch,
      signerDevice: SignerDeviceEntity.seedsigner,
      label: label,
    );
  }
  final key = _Extended();
  when(() => key.network).thenReturn(satoshifier.Network.bitcoinMainnet);
  when(() => key.pubBase58).thenReturn('zpub-public-fixture');
  when(() => key.xpub).thenReturn('xpub-public-fixture');
  when(() => key.derivation).thenReturn(satoshifier.Derivation.bip84);
  final watch = _WatchXpub();
  when(() => watch.extendedPubkey).thenReturn(key);
  return WatchOnlyWalletEntity.xpub(watchOnlyXpub: watch, label: label);
}

void main() {
  tearDown(locator.reset);
  test('preflight rejects a missing wallet without reading settings', () async {
    final settings = _Settings();
    final result = await ValidateWatchOnlyImportUsecase(
      settings: settings,
    ).execute(null);
    expect(result, isA<Err<WatchOnlyWalletEntity, ImportWatchOnlyFailure>>());
    switch (result) {
      case Err(:final failure):
        expect(failure, isA<NoWalletSelectedFailure>());
      case Ok():
        fail('A selected wallet is required');
    }
    verifyZeroInteractions(settings);
  });
  test(
    'preflight maps storage exceptions to a visible feature failure',
    () async {
      final settings = _Settings();
      when(() => settings.fetch()).thenThrow(Exception('storage unavailable'));
      final result = await ValidateWatchOnlyImportUsecase(
        settings: settings,
      ).execute(_wallet(true, 'Savings'));
      switch (result) {
        case Err(:final failure):
          expect(failure, isA<ImportFailedFailure>());
        case Ok():
          fail('Unavailable settings must stop import');
      }
    },
  );
  for (final descriptor in [true, false]) {
    for (final (label, environment, errorKey) in [
      ('', Environment.mainnet, 'label'),
      ('   ', Environment.mainnet, 'label'),
      ('Savings', Environment.testnet, 'network'),
    ]) {
      testWidgets(
        'blocks $errorKey before chooser for ${descriptor ? 'descriptor' : 'xpub'} label "$label"',
        (tester) async {
          final choices = _Choices();
          locator.registerSingleton<WalletSyncFacade>(choices);
          final settings = _Settings();
          when(() => settings.fetch()).thenAnswer(
            (_) async => SettingsEntity(
              environment: environment,
              bitcoinUnit: BitcoinUnit.sats,
              currencyCode: 'USD',
            ),
          );
          final wallet = _wallet(descriptor, label);
          final importDescriptor = _ImportDescriptor();
          final importXpub = _ImportXpub();
          final cubit = ImportWatchOnlyCubit(
            watchOnlyWallet: wallet,
            importWatchOnlyDescriptorUsecase: importDescriptor,
            importWatchOnlyXpubUsecase: importXpub,
            parseWatchOnlyInputUsecase: _Parse(),
            validateImport: ValidateWatchOnlyImportUsecase(settings: settings),
          );
          addTearDown(cubit.close);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.themeData(AppThemeType.light),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: BlocProvider.value(
                value: cubit,
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: WatchOnlyDetailsWidget(watchOnlyWallet: wallet),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Import'));
          await tester.tap(find.text('Import'));
          await tester.pumpAndSettle();
          expect(choices.calls, 0);
          final context = tester.element(find.byType(WatchOnlyDetailsWidget));
          final loc = AppLocalizations.of(context);
          final error = errorKey == 'label'
              ? loc.importWatchOnlyErrorLabelRequired
              : loc.importWatchOnlyErrorNetworkMismatch;
          expect(find.text(error), findsOneWidget);
          final errorText = tester.widget<BullText>(
            find.widgetWithText(BullText, error),
          );
          expect(
            errorText.color,
            Theme.of(context).extension<BullTheme>()?.error,
          );
          verifyZeroInteractions(importDescriptor);
          verifyZeroInteractions(importXpub);
          if (errorKey == 'label') {
            cubit.updateLabel('Savings');
            await tester.pumpAndSettle();
            expect(find.text(error), findsNothing);
            await tester.tap(find.text('Import'));
            await tester.pumpAndSettle();
            expect(choices.calls, 1);
            expect(
              choices.lastInitial?.effectiveScanScriptType,
              wallet.scanScriptType,
            );
          }
        },
      );
    }
  }
}
