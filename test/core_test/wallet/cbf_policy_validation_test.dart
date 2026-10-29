import 'dart:io';

import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/wallet/data/bitcoin_sync_routing.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/wallet_locator.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

class _Settings extends Mock implements SettingsRepository {}

class _Facade extends Mock implements WalletTransactionSyncFacade {}

const _wallet = WalletMetadataModel(
  id: 'wpkh([deadbeef/84h/0h/0h])',
  masterFingerprint: 'deadbeef',
  xpubFingerprint: 'public',
  isEncryptedVaultTested: false,
  isPhysicalBackupTested: false,
  xpub: 'public',
  externalPublicDescriptor: 'wpkh(public/0/*)',
  internalPublicDescriptor: 'wpkh(public/1/*)',
  signer: Signer.none,
  isDefault: false,
  bitcoinSyncSource: BitcoinSyncSource.compactBlockFilters,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final foreground in [false, true]) {
    group(foreground ? 'foreground composition' : 'headless routing', () {
      late Directory directory;
      late SqliteDatabase database;
      late WalletMetadataDatasource wallets;
      late GetIt locator;
      late BitcoinSyncRouting routing;
      late SettingsEntity savedSettings;
      late Future<bool> Function(WalletSourceRegistration) isCurrent;

      setUp(() async {
        directory = await Directory.systemTemp.createTemp('cbf-policy-');
        database = SqliteDatabase(NativeDatabase.memory());
        wallets = WalletMetadataDatasource(sqlite: database);
        locator = GetIt.asNewInstance();
        savedSettings = const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        );
        final settings = _Settings();
        when(() => settings.fetch()).thenAnswer((_) async => savedSettings);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              (call) async => call.method == 'getApplicationDocumentsDirectory'
                  ? directory.path
                  : null,
            );
        if (foreground) {
          locator.registerSingleton<SettingsRepository>(settings);
          locator.registerSingleton<WalletMetadataDatasource>(wallets);
          await WalletLocator.registerRepositories(locator);
          routing = locator<BitcoinSyncRouting>();
          isCurrent = (registration) async {
            // Exercise the production callback before any native wallet/node
            // is opened: valid policies still require foreground discovery.
            final results = await locator<WalletTransactionSyncFacade>()
                .catchUpCbfWallets(
                  [registration],
                  deadline: DateTime.now().toUtc().add(
                    const Duration(seconds: 10),
                  ),
                );
            return switch (results[registration.key]) {
              Err(failure: InitialScanRequiredFailure()) => true,
              Err(failure: WalletSyncDeferredFailure()) => false,
              _ => fail(
                'expected an explicit discovery or stale-policy refusal',
              ),
            };
          };
        } else {
          routing = BitcoinSyncRouting(
            facade: _Facade(),
            settings: settings,
            tor: () => throw StateError('No direct fallback'),
            documentsDirectory: () async => directory.path,
            allWallets: () => wallets.fetchAll(skipUnavailableSources: true),
          );
          isCurrent = routing.isCurrent;
        }
      });

      tearDown(() async {
        await locator.reset();
        await database.close();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              null,
            );
        await directory.delete(recursive: true);
      });

      for (final (script, birthday) in [
        ('pkh', DateTime.utc(2015, 6)),
        ('tr', DateTime.utc(2022, 6)),
        ('wpkh', DateTime.utc(2018, 6)),
      ]) {
        for (final known in [false, true]) {
          test(
            'admits unchanged $script policy with ${known ? 'known' : 'unknown'} birthday',
            () async {
              await wallets.store(
                _wallet.copyWith(
                  externalPublicDescriptor: '$script(public/0/*)',
                  internalPublicDescriptor: '$script(public/1/*)',
                  birthday: known ? birthday : null,
                ),
              );
              final persisted = await wallets.fetch(_wallet.id);
              if (persisted == null) fail('wallet must be persisted');
              final registration = await routing.registration(persisted);
              expect(await isCurrent(registration), isTrue);
              final config = registration.configuration as BdkCbfConfiguration;
              expect(File(config.databaseFilePath).existsSync(), isFalse);
            },
          );
        }
      }

      test(
        'rejects changed history, descriptors, source, Tor and deletion',
        () async {
          final wallet = _wallet.copyWith(birthday: DateTime.utc(2024, 6));
          await wallets.store(wallet);
          final registration = await routing.registration(wallet);
          expect(await isCurrent(registration), isTrue);
          for (final changed in [
            wallet.copyWith(birthday: DateTime.utc(2023, 6)),
            wallet.copyWith(externalPublicDescriptor: 'wpkh(other/0/*)'),
            wallet.copyWith(internalPublicDescriptor: 'wpkh(other/1/*)'),
            wallet.copyWith(bitcoinSyncSource: BitcoinSyncSource.electrum),
          ]) {
            await wallets.store(changed);
            expect(
              await wallets.updateBitcoinSyncSettings(
                changed.id,
                changed.bitcoinSyncSource,
                changed.birthday,
              ),
              isTrue,
            );
            expect(await isCurrent(registration), isFalse);
          }
          await wallets.store(wallet);
          await wallets.updateBitcoinSyncSettings(
            wallet.id,
            wallet.bitcoinSyncSource,
            wallet.birthday,
          );
          savedSettings = savedSettings.copyWith(useTorProxy: true);
          expect(await isCurrent(registration), isFalse);
          savedSettings = savedSettings.copyWith(useTorProxy: false);
          expect(await isCurrent(registration), isTrue);
          await wallets.delete(wallet.id);
          expect(await isCurrent(registration), isFalse);
        },
      );

      test('rejects a different checkpoint hash at the same height', () async {
        await wallets.store(_wallet);
        final original = await routing.registration(_wallet);
        final config = original.configuration as BdkCbfConfiguration;
        final changed = WalletSourceRegistration.withFingerprint(
          key: original.key,
          sourceKind: original.sourceKind,
          configuration: BdkCbfConfiguration(
            externalPublicDescriptor: config.externalPublicDescriptor,
            internalPublicDescriptor: config.internalPublicDescriptor,
            isTestnet: config.isTestnet,
            databaseFilePath: config.databaseFilePath,
            checkpoint: BitcoinSyncCheckpoint(
              height: config.checkpoint.height,
              blockHash: '0' * 64,
            ),
          ),
        );
        expect(await isCurrent(changed), isFalse);
      });

      test('an unknown source only invalidates its own wallet', () async {
        await wallets.store(_wallet);
        final registration = await routing.registration(_wallet);
        const otherId = 'wpkh([cafebabe/84h/0h/0h])';
        await wallets.store(_wallet.copyWith(id: otherId));
        await database.customStatement(
          'UPDATE wallet_metadatas SET bitcoin_sync_source = ? WHERE id = ?',
          ['unsupported', otherId],
        );
        expect(await isCurrent(registration), isTrue);
        await database.customStatement(
          'UPDATE wallet_metadatas SET bitcoin_sync_source = ? WHERE id = ?',
          ['unsupported', _wallet.id],
        );
        expect(await isCurrent(registration), isFalse);
      });
    });
  }
}
