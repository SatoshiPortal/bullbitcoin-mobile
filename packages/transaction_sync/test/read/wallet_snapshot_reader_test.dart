import 'dart:io';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/read.dart';
import 'package:transaction_sync/transaction_sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Directory documents;
  late WalletSnapshotReader reader;
  late BitcoinWalletDescriptor descriptor;
  late FakeRevisions revisions;
  late FakeReadiness readiness;
  late FakeAdmission admission;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('snapshot-test-');
    documents = await Directory('${directory.path}/documents').create();
    final key = WalletKey(id: 'reader-test', network: BitcoinNetwork.testnet);
    revisions = FakeRevisions(key);
    readiness = FakeReadiness();
    admission = FakeAdmission(revisions);
    reader = WalletSnapshotReader(
      documentsDirectory: documents.path,
      readiness: readiness,
      requiredSchemaVersion: 1,
      revisions: revisions,
      liquidAdmission: admission,
    );
    // Published BIP39 test vector; no application key material.
    final mnemonic = bdk.Mnemonic.fromString(
      mnemonic:
          'abandon abandon abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon about',
    );
    final secret = bdk.DescriptorSecretKey(
      networkKind: bdk.NetworkKind.test,
      mnemonic: mnemonic,
      password: null,
    );
    final external = bdk.Descriptor.newBip84(
      secretKey: secret,
      keychainKind: bdk.KeychainKind.external_,
      networkKind: bdk.NetworkKind.test,
    );
    final internal = bdk.Descriptor.newBip84(
      secretKey: secret,
      keychainKind: bdk.KeychainKind.internal,
      networkKind: bdk.NetworkKind.test,
    );
    descriptor = BitcoinWalletDescriptor(
      key: key,
      scriptType: ScriptType.bip84,
      origin: 'test',
      externalDescriptor: external.toString(),
      internalDescriptor: internal.toString(),
    );
    readiness.initializedDescriptor = descriptor;
    external.dispose();
    internal.dispose();
    secret.dispose();
    mnemonic.dispose();
  });
  tearDown(() async => directory.delete(recursive: true));

  void create() {
    final persister = bdk.Persister.newSqlite(
      path: nativeWalletStoragePath(documents.path, descriptor.key),
    );
    final external = bdk.Descriptor(
      descriptor: descriptor.externalDescriptor,
      networkKind: bdk.NetworkKind.test,
    );
    final internal = bdk.Descriptor(
      descriptor: descriptor.internalDescriptor,
      networkKind: bdk.NetworkKind.test,
    );
    final wallet = bdk.Wallet(
      descriptor: external,
      changeDescriptor: internal,
      network: bdk.Network.testnet,
      persister: persister,
      lookahead: 25,
    );
    wallet.revealNextAddress(keychain: bdk.KeychainKind.external_);
    wallet.persist(persister: persister);
    wallet.dispose();
    persister.dispose();
    external.dispose();
    internal.dispose();
  }

  test(
    'read and cached read preserve real bytes and directory listing',
    () async {
      create();
      final before = await fingerprint(documents);
      final first = await reader.bitcoin(descriptor);
      expect(
        first,
        isA<Ok<WalletReadSnapshot<bdk.Wallet>, TransactionSyncFailure>>(),
      );
      final wallet =
          (first as Ok<WalletReadSnapshot<bdk.Wallet>, TransactionSyncFailure>)
              .value
              .wallet;
      // The loaded handle exposes the persisted derivation state.
      expect(
        wallet.nextDerivationIndex(keychain: bdk.KeychainKind.external_),
        1,
      );
      final second = await reader.bitcoin(descriptor);
      expect(
        (second as Ok<WalletReadSnapshot<bdk.Wallet>, TransactionSyncFailure>)
            .value
            .wallet,
        same(wallet),
      );
      expect(await fingerprint(documents), before);
      revisions.state = WalletRevisionState(
        stamp: revisions.state.stamp,
        lifecycle: WalletLifecycle.pendingWrite,
      );
      final stale = await reader.bitcoin(descriptor);
      expect(
        (stale as Ok<WalletReadSnapshot<bdk.Wallet>, TransactionSyncFailure>)
            .value
            .stale,
        isTrue,
      );
      revisions.state = WalletRevisionState(
        stamp: WalletRevision(key: descriptor.key, generation: 1, revision: 0),
        lifecycle: WalletLifecycle.pendingWrite,
      );
      expect(
        await reader.bitcoin(descriptor),
        isA<Err<WalletReadSnapshot<bdk.Wallet>, TransactionSyncFailure>>(),
      );
    },
  );

  test(
    'BDK hydration holds admission and releases before snapshot reads',
    () async {
      create();
      readiness.onCheck = () => expect(admission.active, isTrue);
      expect(await reader.bitcoin(descriptor), isA<Ok>());
      expect(admission.active, isFalse);
    },
  );

  test(
    'BDK busy admission serves a stale cached snapshot without opening',
    () async {
      create();
      expect(await reader.bitcoin(descriptor), isA<Ok>());
      admission.busy = true;
      final result = await reader.bitcoin(descriptor) as Ok;
      expect((result.value as WalletReadSnapshot).stale, isTrue);
    },
  );

  test('missing store is typed and creates nothing', () async {
    final result = await reader.bitcoin(descriptor);
    expect((result as Err).failure, isA<TransactionSyncNotFoundFailure>());
    expect(await documents.list().toList(), isEmpty);
  });

  test('corrupt store is neither repaired nor deleted', () async {
    await File(
      nativeWalletStoragePath(documents.path, descriptor.key),
    ).writeAsString('not a wallet');
    final before = await fingerprint(documents);
    final result = await reader.bitcoin(descriptor);
    expect((result as Err).failure, isA<TransactionSyncNeedsRepairFailure>());
    expect(await fingerprint(documents), before);
  });

  test('uninitialized and old-schema stores are never opened', () async {
    create();
    for (final version in [null, 0]) {
      readiness.schemaVersion = version;
      final before = await fingerprint(documents);
      expect(
        (await reader.bitcoin(descriptor) as Err).failure,
        isA<TransactionSyncBusyFailure>(),
      );
      expect(await fingerprint(documents), before);
    }
  });

  test('revision changed during hydration is never cached', () async {
    create();
    var reads = 0;
    revisions.beforeRead = () {
      if (++reads == 2) {
        revisions.state = WalletRevisionState(
          stamp: WalletRevision(
            key: descriptor.key,
            generation: 1,
            revision: 0,
          ),
          lifecycle: WalletLifecycle.active,
          initializedSchema: 1,
        );
      }
    };
    expect(
      (await reader.bitcoin(descriptor) as Err).failure,
      isA<TransactionSyncBusyFailure>(),
    );
    expect(await reader.bitcoin(descriptor), isA<Ok>());
  });
}

Future<Map<String, String>> fingerprint(Directory directory) async {
  final result = <String, String>{};
  await for (final entry in directory.list(
    recursive: true,
    followLinks: false,
  )) {
    result[entry.path.substring(directory.path.length)] = entry is File
        ? sha256.convert(await entry.readAsBytes()).toString()
        : entry is Directory
        ? 'directory'
        : 'link';
  }
  return result;
}

final class FakeRevisions implements WalletRevisionReader {
  WalletRevisionState state;
  void Function()? beforeRead;
  FakeRevisions(WalletKey key)
    : state = WalletRevisionState(
        stamp: WalletRevision(key: key, generation: 0, revision: 0),
        lifecycle: WalletLifecycle.active,
        initializedSchema: 1,
      );
  @override
  Future<Result<WalletRevisionState, TransactionSyncFailure>> read(
    WalletKey key,
  ) async {
    beforeRead?.call();
    return Ok(state);
  }

  @override
  Stream<WalletRevisionState> watch(WalletKey key) => const Stream.empty();
}

final class FakeAdmission implements LiquidReadAdmission {
  final FakeRevisions revisions;
  bool busy = false;
  bool active = false;
  FakeAdmission(this.revisions);
  @override
  Future<Result<LiquidReadLease, TransactionSyncFailure>> acquire(
    WalletKey key,
  ) async {
    if (busy) return const Err(TransactionSyncBusyFailure());
    active = true;
    return Ok(_FakeLease(revisions.state.stamp, () => active = false));
  }
}

final class _FakeLease implements LiquidReadLease {
  @override
  final WalletRevision revision;
  final void Function() onRelease;
  _FakeLease(this.revision, this.onRelease);
  @override
  Future<void> release() async => onRelease();
}

final class FakeReadiness implements WalletReadReadiness {
  int? schemaVersion = 1;
  String? liquidCachePath;
  PublicWalletDescriptor? initializedDescriptor;
  void Function()? onCheck;

  @override
  Future<Result<WalletReadReady, TransactionSyncFailure>> check(
    PublicWalletDescriptor descriptor,
    WalletRevision expected,
    int requiredSchemaVersion,
  ) async {
    onCheck?.call();
    if (!identical(descriptor, initializedDescriptor)) {
      return const Err(TransactionSyncInvalidCatalogFailure());
    }
    final version = schemaVersion;
    if (version == null) {
      return const Err(TransactionSyncBusyFailure());
    }
    return Ok(
      WalletReadReady(
        revision: expected,
        schemaVersion: version,
        liquidCachePath: liquidCachePath,
      ),
    );
  }
}
