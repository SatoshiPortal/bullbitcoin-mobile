import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/balance_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart'
    hide WalletBirthday;
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_descriptor_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_xpub_usecase.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

class _Bdk extends Mock implements BdkWalletDatasource {}

class _Lwk extends Mock implements LwkWalletDatasource {}

class _Servers extends Mock implements ElectrumServersPort {}

class _SyncMetadata extends Mock implements WalletSyncMetadataPort {}

void main() {
  const xpub =
      'xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8JfuDwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7';
  const descriptor = 'wpkh([86241f88/84h/0h/0h]$xpub/<0;1>/*)#n8txaeah';
  setUpAll(() {
    registerFallbackValue(
      const WalletModel.publicBdk(
        id: 'public',
        externalDescriptor: descriptor,
        internalDescriptor: descriptor,
        isTestnet: false,
      ),
    );
  });
  for (final source in BitcoinSyncSource.values) {
    for (final useDescriptor in [false, true]) {
      for (final birthday in <WalletBirthday?>[
        null,
        WalletBirthday(DateTime.parse('2020-03-02T01:30:00+02:00')),
      ]) {
        test(
          'watch-only creation and domain reads round trip birthday (descriptor=$useDescriptor, known=${birthday != null})',
          () async {
            final db = SqliteDatabase(NativeDatabase.memory());
            addTearDown(db.close);
            final bdk = _Bdk();
            final servers = _Servers();
            when(() => bdk.getBalance(wallet: any(named: 'wallet'))).thenAnswer(
              (_) async => BalanceModel(
                immatureSat: BigInt.zero,
                trustedPendingSat: BigInt.zero,
                untrustedPendingSat: BigInt.zero,
                confirmedSat: BigInt.zero,
                spendableSat: BigInt.zero,
                totalSat: BigInt.zero,
              ),
            );
            final repository = WalletRepository(
              walletMetadataDatasource: WalletMetadataDatasource(sqlite: db),
              bdkWalletDatasource: bdk,
              lwkWalletDatasource: _Lwk(),
              serversPort: servers,
              coordinator: InMemoryWalletSourceOperationCoordinator(),
              syncMetadata: _SyncMetadata(),
            );
            final entity = await WatchOnlyWalletEntity.parse(
              useDescriptor ? descriptor : xpub,
            );
            final Wallet wallet;
            if (entity is WatchOnlyDescriptorEntity) {
              final result =
                  await ImportWatchOnlyDescriptorUsecase(
                    walletRepository: repository,
                  ).execute(
                    watchOnlyDescriptor: entity,
                    birthday: birthday,
                    bitcoinSyncSource: source,
                  );
              expect(result, isA<Ok>());
              wallet = (result as Ok).value as Wallet;
            } else if (entity is WatchOnlyXpubEntity) {
              final result =
                  await ImportWatchOnlyXpubUsecase(
                    walletRepository: repository,
                  ).execute(
                    watchOnlyXpub: entity,
                    birthday: birthday,
                    bitcoinSyncSource: source,
                  );
              expect(result, isA<Ok>());
              wallet = (result as Ok).value as Wallet;
            } else {
              fail('unexpected public watch-only type');
            }
            expect(wallet.birthday, birthday?.dateTime);
            expect(wallet.bitcoinSyncSource, source);
            final one = await repository.getWallet(wallet.id);
            final all = await repository.getWallets();
            expect((one as Ok).value.birthday, birthday?.dateTime);
            expect((all as Ok).value.single.birthday, birthday?.dateTime);
            verifyZeroInteractions(servers);
            // Persisted observations stay readable even after the device clock
            // moves behind a birthday validated at creation time.
            await db.customStatement(
              "UPDATE wallet_metadatas SET birthday = '2099-01-01T00:00:00.000Z'",
            );
            final afterClockRollback = await repository.getWallet(wallet.id);
            expect(
              (afterClockRollback as Ok).value.birthday,
              DateTime.utc(2099),
            );
          },
        );
      }
    }
  }
  for (final date in <DateTime?>[
    null,
    DateTime.parse('2020-03-02T01:30:00+02:00'),
  ]) {
    test(
      'nullable birthday round trips through SQLite in UTC ($date)',
      () async {
        final db = SqliteDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final datasource = WalletMetadataDatasource(sqlite: db);
        final model = WalletMetadataModel(
          id: 'wpkh([deadbeef/84h/0h/0h])',
          masterFingerprint: 'deadbeef',
          xpubFingerprint: 'deadbeef',
          isEncryptedVaultTested: false,
          isPhysicalBackupTested: false,
          xpub: 'public',
          externalPublicDescriptor: 'public',
          internalPublicDescriptor: 'public',
          signer: Signer.none,
          isDefault: false,
          birthday: date,
        );
        await datasource.store(model);
        final restored = await datasource.fetch(model.id);
        expect(restored, isNotNull);
        expect(restored?.birthday, date?.toUtc());
        if (restored?.birthday case final birthday?) {
          expect(birthday.isUtc, isTrue);
          expect(WalletBirthday(birthday).dateTime, date?.toUtc());
        } else {
          expect(date, isNull);
        }
      },
    );
  }
}
