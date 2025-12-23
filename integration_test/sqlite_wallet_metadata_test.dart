import 'package:bb_mobile/core/infra/database/sqlite_database.dart';
import 'package:bb_mobile/core/primitives/network/network.dart';
import 'package:bb_mobile/features/wallets/domain/entities/wallet_entity.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/main.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter_test/flutter_test.dart';

Future<void> main({bool isInitialized = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) await Bull.init();

  final sqlite = locator<SqliteDatabase>();

  group('WalletMetadata Sqlite Integration Tests', () {
    test('can store and fetch a wallet metadata', () async {
      //const fingerprint = 'master';
      //const scriptType = ScriptType.bip84;

      final metadata = WalletEntity.rehydrate(
        id: 1,
        label: 'Secure Bitcoin Wallet',
        network: Network.bitcoin,
        isDefault: true,
        syncedAt: DateTime.now(),
      );

      // Store a metadata
      await sqlite
          .into(sqlite.walletMetadatas)
          .insert(
            WalletMetadatasCompanion.insert(
              id: Value(metadata.id!),
              label: Value(metadata.label),
              network: metadata.network,
              isDefault: metadata.isDefault,
              syncedAt: Value(metadata.syncedAt),
            ),
          );

      // Fetch one
      final fetchedMetadata = await sqlite.managers.walletMetadatas
          .filter((e) => e.id(metadata.id))
          .getSingleOrNull();
      expect(fetchedMetadata, isNotNull);
      expect(fetchedMetadata!.id, metadata.id);

      // Delete the only one
      await sqlite.managers.walletMetadatas
          .filter((f) => f.id(metadata.id))
          .delete();

      // Fetch all
      final fetchedMetadatas = await sqlite.managers.walletMetadatas.get();
      expect(fetchedMetadatas, isEmpty);
    });
  });
}
