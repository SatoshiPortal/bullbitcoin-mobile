import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'package:transaction_sync/src/read/persisted_wallet_readiness.dart';
import 'package:transaction_sync/src/write/revision_store_datasource.dart';
import 'package:transaction_sync/src/write/store_identity.dart';

void main() {
  test('LWK tagged hash matches the pinned native regression vector', () {
    expect(
      liquidDirectoryHash(''),
      '318c87cf9bafe6a65c82e0124e3c2ab31e656d4f64ee8459017b1f9dd91ba818',
    );
  });

  test(
    'readiness requires the committed exact descriptor and revision',
    () async {
      final dir = Directory.systemTemp.createTempSync('readiness-');
      final store = RevisionStoreDatasource.openForeground(
        '${dir.path}/revisions.sqlite',
      );
      final key = WalletKey(id: 'fixture', network: BitcoinNetwork.testnet);
      final descriptor = BitcoinWalletDescriptor(
        key: key,
        scriptType: ScriptType.bip84,
        origin: 'fixture',
        externalDescriptor: 'wpkh(public/0/*)',
        internalDescriptor: 'wpkh(public/1/*)',
      );
      final other = BitcoinWalletDescriptor(
        key: key,
        scriptType: ScriptType.bip84,
        origin: 'fixture',
        externalDescriptor: 'wpkh(other/0/*)',
        internalDescriptor: 'wpkh(other/1/*)',
      );
      final readiness = PersistedWalletReadiness(store);
      try {
        store.begin(key, WriteIntent.create);
        final unproven = store.finish(key).stamp;
        expect(
          (await readiness.check(descriptor, unproven, writerSchemaVersion)
                  as Err)
              .failure,
          isA<TransactionSyncBusyFailure>(),
        );
        store.begin(key, WriteIntent.load);
        final stamp = store
            .finish(key, initializedDescriptor: descriptor)
            .stamp;
        expect(
          await readiness.check(descriptor, stamp, writerSchemaVersion),
          isA<Ok>(),
        );
        expect(
          (await readiness.check(other, stamp, writerSchemaVersion) as Err)
              .failure,
          isA<TransactionSyncInvalidCatalogFailure>(),
        );
        expect(
          (await readiness.check(descriptor, unproven, writerSchemaVersion)
                  as Err)
              .failure,
          isA<TransactionSyncBusyFailure>(),
        );
        expect(
          (await readiness.check(descriptor, stamp, writerSchemaVersion + 1)
                  as Err)
              .failure,
          isA<TransactionSyncBusyFailure>(),
        );
        store.begin(key, WriteIntent.sync);
        expect(
          (await readiness.check(descriptor, stamp, writerSchemaVersion) as Err)
              .failure,
          isA<TransactionSyncBusyFailure>(),
        );
        final uncertain = store.finish(key, needsSync: true).stamp;
        expect(
          (await readiness.check(descriptor, uncertain, writerSchemaVersion)
                  as Err)
              .failure,
          isA<TransactionSyncNeedsRepairFailure>(),
        );
        store.begin(key, WriteIntent.delete);
        final deleted = store.finish(key).stamp;
        expect(
          (await readiness.check(descriptor, deleted, writerSchemaVersion)
                  as Err)
              .failure,
          isA<TransactionSyncNotFoundFailure>(),
        );
        expect(store.record(key)?.descriptorHash, isNull);
        expect(store.record(key)?.liquidCachePath, isNull);
      } finally {
        store.close();
        dir.deleteSync(recursive: true);
      }
    },
  );
}
