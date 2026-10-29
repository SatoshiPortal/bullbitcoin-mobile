import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/electrum_sync_source_guard.dart';
import 'package:bb_mobile/core/wallet/data/models/balance_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:transaction_sync/transaction_sync.dart';

class _Bdk extends Mock implements BdkWalletDatasource {}

class _Lwk extends Mock implements LwkWalletDatasource {}

class _Servers extends Mock implements ElectrumServersPort {}

class _SyncMetadata extends Mock implements WalletSyncMetadataPort {}

// Regression for #2633: duplicate checks must cover imported wallets, before
// an upsert can replace their metadata. Exercise persistence, not SQL API names.
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

  for (final input in [descriptor, xpub]) {
    final kind = input == descriptor ? 'descriptor' : 'xpub';
    test(
      'duplicate imported $kind uses a typed refusal and preserves every field',
      () async {
        final db = SqliteDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final metadata = WalletMetadataDatasource(sqlite: db);
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
          walletMetadataDatasource: metadata,
          bdkWalletDatasource: bdk,
          lwkWalletDatasource: _Lwk(),
          serversPort: servers,
          coordinator: ElectrumSyncSourceGuard(
            coordinator: InMemoryWalletSourceOperationCoordinator(),
            metadata: metadata,
          ),
          syncMetadata: _SyncMetadata(),
        );
        final entity = await WatchOnlyWalletEntity.parse(input);
        Future<Wallet> import({
          required WalletBirthday birthday,
          required BitcoinSyncSource source,
          required String label,
        }) {
          if (entity is WatchOnlyDescriptorEntity) {
            return repository.importDescriptor(
              watchOnlyDescriptor: entity.copyWith(label: label),
              birthday: birthday,
              bitcoinSyncSource: source,
            );
          }
          if (entity is WatchOnlyXpubEntity) {
            return repository.importWatchOnlyXpub(
              xpub: entity.pubkey,
              network: entity.network,
              scriptType: entity.scriptType,
              label: label,
              birthday: birthday,
              bitcoinSyncSource: source,
            );
          }
          throw StateError('unsupported public fixture');
        }

        final original = await import(
          birthday: WalletBirthday(DateTime.utc(2020)),
          source: BitcoinSyncSource.compactBlockFilters,
          label: 'Savings',
        );
        expect(original.isDefault, isFalse);
        final before = await metadata.fetch(original.id);
        expect(before, isNotNull);
        await expectLater(
          import(
            birthday: WalletBirthday(DateTime.utc(2024)),
            source: BitcoinSyncSource.electrum,
            label: 'Replacement',
          ),
          throwsA(isA<WalletAlreadyExistsException>()),
        );
        expect(await metadata.fetchAll(), [before]);
        expect(
          (await metadata.fetch(original.id))?.bitcoinSyncSource,
          BitcoinSyncSource.compactBlockFilters,
        );
        expect(
          (await metadata.fetch(original.id))?.birthday,
          DateTime.utc(2020),
        );
        verifyZeroInteractions(servers);
      },
    );
  }
}
