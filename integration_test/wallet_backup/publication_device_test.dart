import 'dart:io';
import 'package:bb_mobile/core/bip85/data/bip85_datasource.dart';
import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_settings_storage_datasource.dart';
import 'package:bb_mobile/core/mempool/frameworks/drift/datasources/mempool_server_storage_datasource.dart';
import 'package:bb_mobile/core/mempool/frameworks/drift/datasources/mempool_settings_storage_datasource.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/seed_verification_port.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_datasource.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart'
    as settings_data;
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart'
    as settings_domain;
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/auto_swap_settings_repository.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/data/datasources/frozen_wallet_utxo_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_signer_device_port.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/manage_data_backup_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/update_data_backup_lifecycle_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/data_backup_settings_cubit.dart';
import 'package:bb_mobile/features/backup_settings/public/backup_settings_facade.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/data_backup_settings_screen.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/keychain_manifest_locator.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/nostr_identity/domain/backup_credential_resolver.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bb_mobile/features/wallet_backup/data/backup_server_http_transport.dart';
import 'package:bb_mobile/features/wallet_backup/data/wallet_backup_remote_repository_impl.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_codec_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_file_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_remote_repository.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/features/wallet_backup/wallet_backup_locator.dart';
import 'package:bb_mobile/features/wizard/public/wizard_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../test/features/nostr_identity/fixtures/backup_credential_vectors.dart';

class _Defaults extends Mock implements GetDefaultSeedUsecase {}

class _Settings extends Mock implements GetSettingsUsecase {}

class _SettingsFacade extends Mock implements SettingsFacade {}

class _Policy extends Mock implements PayjoinPolicyAccess {}

class _Swaps extends Mock implements AutoSwapSettingsRepository {}

class _Vaults extends Mock implements BullVaultFacade {}

class _Wizard extends Mock implements WizardFacade {}

class _Descriptors extends Fake implements BitcoinDescriptorPort {}

class _Seeds extends Fake implements SeedVerificationPort {}

class _SignerDevices extends Fake implements WalletSignerDevicePort {}

// Only the OS document-picker boundary is replaced; the files are written and decoded on Android.
class _Files implements WalletBackupFileRepository {
  final Directory directory;
  final saved = <WalletBackupFileFormat, File>{};
  _Files(this.directory);
  @override
  Future<Result<String?, WalletBackupFailure>> pick() async =>
      Ok(await saved.values.last.readAsString());
  @override
  Future<Result<bool, WalletBackupFailure>> save(
    String source, {
    required WalletBackupFileFormat format,
  }) async {
    final file = File('${directory.path}/${format.name}.json');
    await file.writeAsString(source);
    saved[format] = file;
    return const Ok(true);
  }
}

T _value<T>(Result<T, WalletBackupFailure> result) => result.fold(
  (value) => value,
  (failure) => throw StateError(failure.runtimeType.toString()),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'consent and readiness start real capture and publication; owner edits upload, Off stops, files round trip',
    (tester) async {
      await locator.reset();
      const origin = String.fromEnvironment(
        'BULL_BACKUP_DEVICE_ORIGIN',
        defaultValue: 'http://10.0.2.2:46085',
      );
      final uri = Uri.parse(origin);
      expect({'10.0.2.2', '127.0.0.1', 'localhost'}.contains(uri.host), isTrue);
      final directory = await Directory.systemTemp.createTemp(
        'bull-device-publication-',
      );
      final database = SqliteDatabase(
        NativeDatabase(File('${directory.path}/state.sqlite')),
      );
      final defaults = _Defaults();
      final getSettings = _Settings();
      var seedReads = 0, stores = 0;
      when(() => getSettings.execute()).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      );
      when(() => defaults.execute(environment: Environment.mainnet)).thenAnswer(
        (_) async {
          seedReads++;
          return Seed.bytes(
            bytes: backupCredentialVectorSeed,
            masterFingerprint: 'aabbccdd',
          );
        },
      );
      final identity = NostrIdentityFacade(
        BackupCredentialResolver(
          getDefaultSeed: defaults,
          getSettings: getSettings,
        ),
      );
      locator.registerSingleton<SqliteDatabase>(database);
      final wallets = WalletMetadataDatasource(sqlite: database);
      final bip85 = Bip85Datasource(sqlite: database);
      locator.registerSingleton<WalletMetadataDatasource>(wallets);
      locator.registerSingleton<Bip85Datasource>(bip85);
      locator.registerSingleton<Bip85Repository>(
        Bip85Repository(datasource: bip85),
      );
      locator.registerSingleton<NostrIdentityFacade>(identity);
      locator.registerSingleton<SettingsFacade>(_SettingsFacade());
      KeychainManifestLocator.setup(locator);
      LabelsLocator.registerPorts(locator);
      LabelsLocator.registerFrameworks(locator);
      LabelsLocator.registerUseCases(locator);
      LabelsLocator.registerFacade(locator);
      final settings = SettingsDatasource(sqlite: database);
      final settingsWriter = settings_data.SettingsRepository(
        settingsDatasource: settings,
      );
      locator.registerSingleton<SettingsDatasource>(settings);
      locator.registerSingleton<settings_domain.SettingsRepository>(
        settingsWriter,
      );
      locator.registerSingleton<FrozenWalletUtxoDatasource>(
        FrozenWalletUtxoDatasource(db: database),
      );
      locator.registerSingleton<ElectrumServerStorageDatasource>(
        ElectrumServerStorageDatasource(sqlite: database),
      );
      locator.registerSingleton<ElectrumSettingsStorageDatasource>(
        ElectrumSettingsStorageDatasource(sqlite: database),
      );
      locator.registerSingleton<MempoolServerStorageDatasource>(
        MempoolServerStorageDatasource(sqlite: database),
      );
      locator.registerSingleton<MempoolSettingsStorageDatasource>(
        MempoolSettingsStorageDatasource(sqlite: database),
      );
      final policy = _Policy(),
          swaps = _Swaps(),
          vaults = _Vaults(),
          wizard = _Wizard();
      when(policy.load).thenAnswer((_) async => Ok(PayjoinPolicy.defaults()));
      when(policy.watch).thenAnswer((_) => const Stream.empty());
      when(swaps.getAutoSwapParams).thenAnswer((_) async => const AutoSwap());
      when(swaps.watchAutoSwapParams).thenAnswer((_) => const Stream.empty());
      when(vaults.listRecords).thenAnswer((_) async => const Ok([]));
      when(vaults.watchRecords).thenAnswer((_) => const Stream.empty());
      when(
        wizard.applyPendingBackupChoice,
      ).thenAnswer((_) async => const Ok(null));
      locator.registerSingleton<PayjoinPolicyAccess>(policy);
      locator.registerSingleton<AutoSwapSettingsRepository>(swaps);
      locator.registerSingleton<BullVaultFacade>(vaults);
      locator.registerSingleton<BitcoinDescriptorPort>(_Descriptors());
      locator.registerSingleton<SeedVerificationPort>(_Seeds());
      locator.registerSingleton<WalletSignerDevicePort>(_SignerDevices());
      WalletBackupLocator.setup(locator);
      final dio = Dio(BaseOptions(headers: {'X-Real-IP': '127.0.0.1'}));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'PUT') stores++;
            handler.next(options);
          },
        ),
      );
      final remote = WalletBackupRemoteRepositoryImpl(
        BackupServerHttpTransport(dio: dio, origin: uri),
      );
      await locator.unregister<WalletBackupRemoteRepository>();
      locator.registerSingleton<WalletBackupRemoteRepository>(remote);
      final files = _Files(directory);
      await locator.unregister<WalletBackupFileRepository>();
      locator.registerSingleton<WalletBackupFileRepository>(files);
      final backups = locator<WalletBackupFacade>();
      locator.registerSingleton<UpdateDataBackupLifecycleUsecase>(
        UpdateDataBackupLifecycleUsecase(backups, wizard),
      );
      final cubit = DataBackupSettingsCubit(
        LoadDataBackupStatusUsecase(backups),
        WatchDataBackupStatusUsecase(backups),
        SetDataBackupEnabledUsecase(backups),
        PublishDataBackupUsecase(backups),
        DeleteDataBackupUsecase(backups),
      );
      final ready = ValueNotifier(false);
      addTearDown(() async {
        await backups.stopAutomatic();
        await cubit.close();
        ready.dispose();
        await locator.reset();
        await settingsWriter.close();
        dio.close(force: true);
        await database.close();
        await directory.delete(recursive: true);
      });
      await settings.fetch();
      const wallet = WalletMetadataModel(
        id: 'device-wallet',
        network: Network.bitcoinMainnet,
        signers: [],
        isEncryptedVaultTested: false,
        isPhysicalBackupTested: false,
        publicDescriptor: 'public-device-fixture-descriptor',
        isDefault: true,
        label: 'Before edit',
      );
      await wallets.store(wallet);
      await cubit.start();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ValueListenableBuilder<bool>(
            valueListenable: ready,
            builder: (_, value, _) => BackupSettingsScope(
              ready: value,
              child: BlocProvider.value(
                value: cubit,
                child: DataBackupSettingsScreen(
                  onContents: (_) async {},
                  onWords: () async {},
                  onRecovery: () async {},
                  onRecoverWords: () async {},
                  fileActions: const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(seedReads, 0);
      expect(stores, 0);
      ready.value = true;
      await tester.pumpAndSettle();
      expect(seedReads, 0);
      expect(stores, 0);
      await tester.tap(find.byKey(const ValueKey('data-backup-enabled')));
      await tester.pumpAndSettle();
      expect(seedReads, 0);
      await tester.tap(find.text(AppLocalizationsEn().dataBackupEnable));
      Future<void> settledPublication() async {
        for (var count = 0; count < 100; count++) {
          await tester.pump(const Duration(milliseconds: 100));
          final status = backups.publicationStatus;
          if (status.result case Ok(
            value: WalletBackupPublication.published ||
                WalletBackupPublication.upToDate,
          ) when !status.running) {
            return;
          }
          if (status.result case Err(:final failure)) {
            fail('Publication failed: ${failure.runtimeType}');
          }
        }
        fail('No automatic publication acknowledgement arrived');
      }

      await settledPublication();
      expect(stores, 1);
      final first = _value(await backups.inspect());
      expect(first.snapshot!.manifest.wallets.single.label, 'Before edit');
      await wallets.store(wallet.copyWith(label: 'Edited in app'));
      await settings.setCurrency('USD');
      await tester.pump(const Duration(milliseconds: 600));
      await settledPublication();
      final edited = _value(await backups.inspect());
      expect(edited.snapshot!.manifest.wallets.single.label, 'Edited in app');
      expect(edited.snapshot!.metadata.settings.app.currency, 'USD');
      expect(stores, 2);
      await tester.tap(find.byKey(const ValueKey('data-backup-enabled')));
      await tester.pumpAndSettle();
      expect(_value(await backups.getControl()).enabled, isFalse);
      final readsWhileOff = seedReads;
      await wallets.store(wallet.copyWith(label: 'Local after Off'));
      await tester.pump(const Duration(seconds: 1));
      expect(stores, 2);
      expect(seedReads, readsWhileOff);
      final codec = locator<WalletBackupCodecRepository>();
      for (final format in WalletBackupFileFormat.values) {
        expect(
          _value(await backups.exportFile(format, confirmed: true)),
          isTrue,
        );
        final credential =
            (await identity.resolve()
                    as Ok<BackupCredential, NostrIdentityFailure>)
                .value;
        final decoded = _value(
          codec.decodeFile(
            await files.saved[format]!.readAsString(),
            credential: credential,
          ),
        );
        expect(
          decoded.snapshot.manifest.wallets.single.label,
          'Local after Off',
        );
      }
      expect(stores, 2);
      expect(_value(await backups.getControl()).enabled, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
