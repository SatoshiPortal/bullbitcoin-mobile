import 'dart:io';

import 'package:bull_sdk/bull_sdk.dart' show BullSdk;
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/read.dart';
import 'package:transaction_sync/write.dart';
import 'package:transaction_sync/transaction_sync.dart';

import '../test/read/wallet_snapshot_reader_test.dart'
    show FakeRevisions, FakeReadiness, fingerprint;

// Run with the pinned bull_sdk host library on LD_LIBRARY_PATH.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => BullSdk.init());

  test('writer attests the canonical Liquid cache for a production reader', () async {
    final root = Directory.systemTemp.createTempSync('writer-readiness-');
    final revisions = RevisionStore(writerMetadataPath(root.path));
    final key = WalletKey(id: 'fixture', network: LiquidNetwork.testnet);
    final native = await lwk.Descriptor.newConfidential(
      network: lwk.LiquidNetwork.testnet,
      mnemonic:
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
    );
    final descriptor = LiquidWalletDescriptor(
      key: key,
      scriptType: ScriptType.bip84,
      origin: 'fixture',
      combinedCtDescriptor: native.ctDescriptor,
    );
    final catalog = _Catalog(descriptor);
    final writer = NativeWalletWriterRepository(
      lockDirectory: writerLockDirectory(root.path),
      revisions: revisions,
      documentsDirectory: root.path,
      catalog: catalog,
      reservedAddresses: _Reserved(),
    );
    try {
      expect(await writer.create(key, expectedGeneration: 0), isA<Ok>());
      final reader = WalletSnapshotReader(
        documentsDirectory: root.path,
        readiness: PersistedWalletReadiness(revisions),
        requiredSchemaVersion: writerSchemaVersion,
        revisions: revisions,
        liquidAdmission: writer,
      );
      expect(await reader.liquid(descriptor), isA<Ok>());
      // A changed catalog must be refused before LWK can create a second cache.
      final other = await lwk.Descriptor.newConfidential(
        network: lwk.LiquidNetwork.testnet,
        mnemonic:
            'legal winner thank year wave sausage worth useful legal winner thank yellow',
      );
      catalog.descriptor = LiquidWalletDescriptor(
        key: key,
        scriptType: ScriptType.bip84,
        origin: 'fixture',
        combinedCtDescriptor: other.ctDescriptor,
      );
      final before = await fingerprint(
        Directory(nativeWalletStoragePath(root.path, key)),
      );
      expect(
        (await writer.create(key, expectedGeneration: 1) as Err).failure,
        isA<TransactionSyncInvalidCatalogFailure>(),
      );
      expect(
        await fingerprint(Directory(nativeWalletStoragePath(root.path, key))),
        before,
      );
    } finally {
      await revisions.close();
      root.deleteSync(recursive: true);
    }
  });

  test(
    'Liquid hydration holds admission and preserves real store bytes',
    () async {
      final root = await Directory.systemTemp.createTemp('liquid-snapshot-');
      addTearDown(() => root.delete(recursive: true));
      final documents = await Directory('${root.path}/documents').create();
      final key = WalletKey(
        id: 'liquid-reader',
        network: LiquidNetwork.testnet,
      );
      final nativeDescriptor = await lwk.Descriptor.newConfidential(
        network: lwk.LiquidNetwork.testnet,
        mnemonic:
            'abandon abandon abandon abandon abandon abandon abandon abandon '
            'abandon abandon abandon about',
      );
      final descriptor = LiquidWalletDescriptor(
        key: key,
        scriptType: ScriptType.bip84,
        origin: 'test',
        combinedCtDescriptor: nativeDescriptor.ctDescriptor,
      );
      final source = nativeWalletStoragePath(documents.path, key);
      final wallet = await lwk.Wallet.init(
        network: lwk.LiquidNetwork.testnet,
        dbpath: source,
        descriptor: nativeDescriptor,
      );
      final address = await wallet.address(index: 0);
      wallet.dispose();
      final revisions = FakeRevisions(key);
      final admission = FakeAdmission(revisions);
      final store =
          (await Directory(source)
                  .list(recursive: true)
                  .where(
                    (entry) =>
                        entry is Directory &&
                        entry.parent.path.split('/').last == 'enc_cache',
                  )
                  .toList())
              .single;
      final readiness = FakeReadiness()
        ..initializedDescriptor = descriptor
        ..liquidCachePath = store.path.substring(source.length + 1)
        ..onCheck = () => expect(admission.acquired, admission.released + 1);
      final reader = WalletSnapshotReader(
        documentsDirectory: documents.path,
        readiness: readiness,
        requiredSchemaVersion: 1,
        revisions: revisions,
        liquidAdmission: admission,
      );
      final before = await fingerprint(documents);
      final result = await reader.liquid(descriptor);
      expect(
        result,
        isA<Ok<WalletReadSnapshot<lwk.Wallet>, TransactionSyncFailure>>(),
      );
      final snapshot =
          (result as Ok<WalletReadSnapshot<lwk.Wallet>, TransactionSyncFailure>)
              .value;
      expect(
        (await snapshot.wallet.address(index: 0)).confidential,
        address.confidential,
      );
      expect(await fingerprint(documents), before);
      expect(admission.acquired, 1);
      expect(admission.released, 1);
      // A second published BIP39 vector produces a different native cache.
      final otherNative = await lwk.Descriptor.newConfidential(
        network: lwk.LiquidNetwork.testnet,
        mnemonic:
            'legal winner thank year wave sausage worth useful legal winner thank yellow',
      );
      final other = LiquidWalletDescriptor(
        key: key,
        scriptType: ScriptType.bip84,
        origin: 'test',
        combinedCtDescriptor: otherNative.ctDescriptor,
      );
      final uncached = WalletSnapshotReader(
        documentsDirectory: documents.path,
        readiness: readiness,
        requiredSchemaVersion: 1,
        revisions: revisions,
        liquidAdmission: admission,
      );
      final beforeMismatch = await fingerprint(documents);
      expect(await uncached.liquid(other), isA<Err>());
      expect(await reader.liquid(other), isA<Err>());
      expect(await fingerprint(documents), beforeMismatch);
      // A corrupt update must never trigger the legacy delete/recreate path.
      await File('${store.path}/000000000000').writeAsString('corrupt update');
      revisions.state = WalletRevisionState(
        stamp: WalletRevision(key: key, generation: 0, revision: 1),
        lifecycle: WalletLifecycle.active,
        initializedSchema: 1,
      );
      final corruptBefore = await fingerprint(documents);
      expect(await reader.liquid(descriptor), isA<Err>());
      expect(await fingerprint(documents), corruptBefore);
      expect(admission.released, admission.acquired);

      await File('${store.path}/000000000000').delete();
      final outside = await File(
        '${root.path}/outside',
      ).writeAsString('not an update');
      await Link('${store.path}/000000000000').create(outside.path);
      expect(
        (await reader.liquid(descriptor) as Err).failure,
        isA<TransactionSyncNeedsRepairFailure>(),
      );
      expect(await outside.readAsString(), 'not an update');
      expect(admission.released, admission.acquired);

      await Directory(source).delete(recursive: true);
      expect(
        (await reader.liquid(descriptor) as Err).failure,
        isA<TransactionSyncNotFoundFailure>(),
      );
      expect(await Directory(source).exists(), isFalse);
      expect(admission.released, admission.acquired);
      await Directory(source).create();
      expect(
        (await reader.liquid(descriptor) as Err).failure,
        isA<TransactionSyncNotFoundFailure>(),
      );
      expect(await Directory(source).list().toList(), isEmpty);
      readiness.schemaVersion = null;
      final stale = await reader.liquid(descriptor);
      expect(
        (stale as Ok<WalletReadSnapshot<lwk.Wallet>, TransactionSyncFailure>)
            .value
            .stale,
        isTrue,
      );
      // A reader with no previous snapshot must return Busy without hydration.
      final uninitialized = WalletSnapshotReader(
        documentsDirectory: documents.path,
        readiness: readiness,
        requiredSchemaVersion: 1,
        revisions: revisions,
        liquidAdmission: admission,
      );
      expect(
        (await uninitialized.liquid(descriptor) as Err).failure,
        isA<TransactionSyncBusyFailure>(),
      );
      expect(await Directory(source).list().toList(), isEmpty);
    },
  );
}

final class FakeAdmission implements ReadAdmissionPort {
  final FakeRevisions revisions;
  int acquired = 0;
  int released = 0;
  FakeAdmission(this.revisions);
  @override
  Future<Result<ReadLease, TransactionSyncFailure>> acquire(
    WalletKey key,
  ) async {
    acquired++;
    return Ok(
      FakeLease(revisions.state.stamp, () {
        released++;
      }),
    );
  }
}

final class FakeLease implements ReadLease {
  @override
  final WalletRevision revision;
  final void Function() onRelease;
  FakeLease(this.revision, this.onRelease);
  @override
  Future<void> release() async => onRelease();
}

final class _Catalog implements WalletCatalogPort {
  PublicWalletDescriptor descriptor;
  _Catalog(this.descriptor);
  @override
  Future<Result<PublicWalletDescriptor, TransactionSyncFailure>> find(
    WalletKey key,
  ) async => Ok(descriptor);
  @override
  Future<Result<List<PublicWalletDescriptor>, TransactionSyncFailure>>
  list() async => Ok([descriptor]);
}

final class _Reserved implements ReservedAddressPort {
  @override
  Future<Result<bool, TransactionSyncFailure>> isReserved(
    WalletKey key,
    String address,
  ) async => const Ok(false);
}
