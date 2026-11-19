import 'dart:convert';
import 'dart:io';

import 'package:ark/ark.dart';
import 'package:bb_mobile/core/fees/domain/repositories/fees_repository.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart'
    show Signer;
import 'package:bb_mobile/features/wallet/data/ark_board_funding.dart';
import 'package:bb_mobile/features/wallet/data/foreground_wallet_sync.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/data/sqlite_ark_funding_reservations.dart';
import 'package:bb_mobile/features/wallet/data/sqlite_parent_custody_admission.dart';
import 'package:bb_mobile/features/wallet/data/wallet_catalog_port_impl.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/wallet/data/wallet_native_runtime.dart';
import 'package:bull_ark/ark_setup.dart';
import 'package:rust_bindings/bdk.dart' as bdk;
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sync/sync.dart';
import 'package:sync/testing.dart' show MemoryFreezeStore;
import 'package:sync/write.dart';

import '../../../../packages/sync/test/support/connections.dart';
import '../../../../packages/sync/test/support/electrum_fixture.dart';

class _Metadata extends Mock implements WalletMetadataDatasource {}

// Keystore assertions isolate the Bitcoin PSBT signer; production Bark
// synchronize/quote also derive their child through Secrets.
class _Client extends Mock implements ArkClient {}

class _Fees extends Mock implements FeesRepository {}

class _Reserved implements ReservedAddressPort {
  @override
  Future<Result<bool, SyncFailure>> isReserved(
    WalletKey key,
    String address,
  ) async => const Ok(false);
}

T _ok<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err() => throw StateError('Fixture setup refused: ${result.runtimeType}'),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late ElectrumFixture server;
  late WalletNativeRuntime runtime;
  late ForegroundWalletSync source;
  late SqliteArkFundingReservations store;
  late WalletArkBoardFunding actor;
  late _Metadata metadata;
  late _Client client;
  late Secrets secrets;
  late FakeSecureStoragePlatform keystore;
  late WalletMetadataModel row;
  late ArkAccountId account;
  late ArkFundingBinding binding;
  late String token;
  late String destination;
  late String payload;
  late ArkOperation operation;
  late ElectrumSync engine;
  late FixtureConnections connections;
  int tip = 9990;
  bool syncUnavailable = false;
  final chainSource = Uri.parse('http://chain.invalid');

  WalletArkBoardFunding openActor() => WalletArkBoardFunding(
    client: client,
    runtime: runtime,
    authority: store,
    metadata: metadata,
    sourceSync: source,
    secrets: secrets,
    fees: _Fees(),
    custody: SqliteParentCustodyAdmission(
      directory: () async => root.path,
      mayCreate: true,
    ),
    sourceWalletId: (_) async => row.id,
  );
  WalletNativeRuntime openRuntime() => WalletNativeRuntime(
    catalog: WalletCatalogPortImpl(metadata),
    reserved: _Reserved(),
    inputReservations: store,
    fundingReservations: store,
    metadata: metadata,
    sync: engine,
    documentsDirectory: () async => root.path,
    freezes: MemoryFreezeStore(),
    connections: connections,
  );
  Future<void> restart() async {
    await actor.close();
    await runtime.close();
    store.close();
    store = _ok(
      SqliteArkFundingReservations.open(
        '${root.path}/funding.sqlite',
        foreground: true,
      ),
    );
    runtime = openRuntime();
    source = ForegroundWalletSync(engine, native: runtime);
    actor = openActor();
  }

  Future<void> seal() async {
    final handle = await runtime.wallet(row.id);
    final loaded = _ok(await handle.load());
    final lease = await (await runtime.foreground()).stores.spendGate.acquire(
      binding.key,
    );
    expect(lease, isA<BitcoinSpendAdmission>());
    if (lease is! BitcoinSpendAdmission) {
      throw StateError('No source admission');
    }
    try {
      expect(lease.revision, loaded);
      _ok(
        await store.admitBoardSigning(
          expected: binding,
          admittedRevision: lease.revision,
        ),
      );
    } finally {
      lease.close();
    }
  }

  Future<String> sign() async {
    final secret = _ok(await secrets.fetch(account.parent));
    return _ok(
      await secret.sign.psbt(
        binding.unsignedPsbt,
        network: BitcoinNetwork.regtest,
        scriptType: ScriptType.bip84,
      ),
    );
  }

  void failPhase(String phase) {
    final db = sqlite3.open('${root.path}/funding.sqlite');
    try {
      db.execute(
        "CREATE TRIGGER kill_window BEFORE UPDATE OF phase ON ark_board_reviews WHEN NEW.phase='$phase' BEGIN SELECT RAISE(ABORT, 'injected interruption'); END",
      );
    } finally {
      db.close();
    }
  }

  void clearFault() {
    final db = sqlite3.open('${root.path}/funding.sqlite');
    try {
      db.execute('DROP TRIGGER kill_window');
    } finally {
      db.close();
    }
  }

  Future<void> settled() async {
    expect(
      _ok(await store.reservations()),
      isNotEmpty,
      reason: 'An unconfirmed acceptance must retain every source hold',
    );
    await server.confirmBroadcast(binding.unsignedTxid);
    expect(
      await actor.reconcileSource('operation'),
      isA<Ok<void, ArkFailure>>(),
    );
    expect(_ok(await store.reservations()), isEmpty);
    expect(_ok(await store.pendingForAccount(account.canonical)), isNull);
  }

  setUp(() async {
    tip = 9990;
    syncUnavailable = false;
    root = Directory.systemTemp.createTempSync('ark-board-recovery-');
    keystore = FakeSecureStoragePlatform().install();
    secrets = Secrets(scratchDirectory: () async => root.path);
    // Published BIP39 vector; no device wallet material is used by this fixture.
    final secret = _ok(
      await secrets.import(
        words: [...List.filled(11, 'abandon'), 'about'],
        language: Language.english,
      ),
    );
    account = ArkAccountId(
      parent: secret.info.id,
      network: BitcoinNetwork.regtest,
      serverIdentity: 'public-server',
    );
    final mnemonic = bdk.Mnemonic.fromString(
      mnemonic: '${List.filled(11, 'abandon').join(' ')} about',
    );
    final key = bdk.DescriptorSecretKey(
      networkKind: bdk.NetworkKind.test,
      mnemonic: mnemonic,
      password: null,
    );
    bdk.Descriptor derive(bdk.KeychainKind chain) => bdk.Descriptor.newBip84(
      secretKey: key,
      keychainKind: chain,
      networkKind: bdk.NetworkKind.test,
    );
    final external = derive(bdk.KeychainKind.external_);
    final internal = derive(bdk.KeychainKind.internal);
    final persister = bdk.Persister.newInMemory();
    final wallet = bdk.Wallet(
      descriptor: external,
      changeDescriptor: internal,
      network: bdk.Network.regtest,
      persister: persister,
      lookahead: 25,
    );
    final scripts = <String, String>{};
    for (final (name, chain, count) in [
      ('ext', bdk.KeychainKind.external_, 6),
      ('int', bdk.KeychainKind.internal, 3),
    ]) {
      for (var i = 0; i < count; i++) {
        final script = wallet
            .peekAddress(keychain: chain, index: i)
            .address
            .scriptPubkey();
        try {
          scripts['$name$i'] = script
              .toBytes()
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join();
        } finally {
          script.dispose();
        }
      }
    }
    final target = wallet
        .peekAddress(keychain: bdk.KeychainKind.external_, index: 10)
        .address
        .scriptPubkey();
    try {
      destination = _ok(
        bitcoinScriptAddress(target.toBytes(), BitcoinNetwork.regtest),
      );
    } finally {
      target.dispose();
    }
    row = WalletMetadataModel(
      id: '[${account.parent.hex}/84h/1h/0h]:regtest',
      networkCode: 'bitcoinRegtest',
      masterFingerprint: account.parent.hex,
      xpubFingerprint: account.parent.hex,
      isEncryptedVaultTested: false,
      isPhysicalBackupTested: false,
      xpub: 'public',
      externalPublicDescriptor: external.toString(),
      internalPublicDescriptor: internal.toString(),
      signer: Signer.local,
      isDefault: true,
    );
    wallet.dispose();
    persister.dispose();
    external.dispose();
    internal.dispose();
    key.dispose();
    mnemonic.dispose();
    server = await ElectrumFixture.start(scripts, regtest: true);
    await server.load('S10-no-change', 0);
    await server.exposeBroadcasts(false);
    metadata = _Metadata();
    when(() => metadata.fetchAll()).thenAnswer((_) async => [row]);
    when(() => metadata.fetch(row.id)).thenAnswer((_) async => row);
    connections = FixtureConnections([server.url]);
    store = _ok(
      SqliteArkFundingReservations.open(
        '${root.path}/funding.sqlite',
        foreground: true,
        initializeNew: true,
      ),
    );
    engine = ElectrumSync(
      connections: connections,
      documentsDirectory: () async => root.path,
      readRevision: (key) => runtime.readRevision(key),
    );
    runtime = openRuntime();
    await runtime.create(row);
    source = ForegroundWalletSync(engine, native: runtime);
    await source.synchronize(row, reason: SyncReason.manual);
    final handle = await runtime.wallet(row.id);
    final context = jsonEncode({
      'version': 1, 'account': account.canonical, 'quoteId': 'public-quote',
      'amount': '20000', 'arkFee': '330', 'net': '19670', 'fastSatPerKwu': 500,
      // Recovery must not demand a new quote after the irreversible seal.
      'validUntil': DateTime.now()
          .toUtc()
          .subtract(const Duration(minutes: 1))
          .toIso8601String(),
      'chainSource': chainSource.toString(), 'configGeneration': 1,
      'arkUrl': 'http://server.invalid',
      'primary': chainSource.toString(),
      'fallback': null,
    });
    _ok(
      await store.beginBoardRequest(
        operationId: 'operation',
        accountIdentity: account.canonical,
        sourceParent: account.parent,
        key: handle.key,
        generation: handle.generation,
        context: context,
      ),
    );
    final built = _ok(
      await handle.tx.prepareFunding(
        BitcoinSpendRequest(
          recipients: [SpendRecipient(destination, amountSat: 20000)],
          fee: SpendFeeRate(500),
          owner: SpendOwner(protocol: 'ark', session: 'operation'),
        ),
        context: context,
      ),
    );
    binding = _ok(await store.readBinding('operation'));
    final facts = _ok(inspectBitcoinPsbt(built.encoded));
    payload = jsonEncode({
      'request': context,
      'address': destination,
      'keypairIndex': 7,
      'expiryHeight': 10000,
      'minerFee': facts.feeSat,
    });
    token = sha256
        .convert(utf8.encode('${built.encoded}\n$payload'))
        .toString();
    operation = ArkOperation(
      id: 'operation',
      kind: ArkOperationKind.board,
      status: ArkOperationStatus.pending,
      chainSource: chainSource,
      configGeneration: 1,
      nativeReference: binding.unsignedTxid,
      boardFunding: ArkBoardFundingDetails(
        address: destination,
        keypairIndex: 7,
        expiryHeight: 10000,
      ),
    );
    client = _Client();
    when(() => client.read(account)).thenAnswer(
      (_) async => Ok(
        ArkSnapshot(
          account: account,
          revision: 1,
          observedAt: DateTime.now().toUtc(),
          stale: false,
          operations: [operation],
        ),
      ),
    );
    when(() => client.synchronize(account, renew: false)).thenAnswer((_) async {
      if (syncUnavailable) return const Err(ArkUnavailableFailure());
      return Ok(
        ArkPassOutcome(
          snapshot: ArkSnapshot(
            account: account,
            revision: 1,
            observedAt: DateTime.now().toUtc(),
            tipHeight: tip,
            stale: false,
            operations: [operation],
          ),
        ),
      );
    });
    actor = openActor();
  });
  tearDown(() async {
    await actor.close();
    await runtime.close();
    store.close();
    server.close();
    root.deleteSync(recursive: true);
  });

  Future<String> persisted(String phase) async {
    _ok(await store.saveBoardReview('operation', payload));
    await seal();
    final signed = await sign();
    _ok(await store.recordSigned('operation', signed));
    if (phase != 'signing') {
      _ok(
        await store.advanceBoardDelivery(
          'operation',
          expectedPhase: 'signing',
          nextPhase: 'signed',
        ),
      );
    }
    if (phase == 'broadcasting') {
      _ok(
        await store.advanceBoardDelivery(
          'operation',
          expectedPhase: 'signed',
          nextPhase: 'broadcasting',
        ),
      );
    }
    return signed;
  }

  test('confirmed funding closes holds even at five blocks', () async {
    final signed = await persisted('broadcasting');
    _ok(
      await runtime.broadcast(
        row.id,
        SignedPsbt(signed),
        network: BitcoinNetwork.regtest,
        built: UnsignedSpend(
          revision: binding.revision,
          encoded: binding.unsignedPsbt,
          inputs: binding.inputs,
          owner: SpendOwner(protocol: 'ark', session: 'operation'),
        ),
      ),
    );
    expect(
      (await server.requests()).counts['blockchain.transaction.broadcast'],
      1,
    );
    await server.confirmBroadcast(binding.unsignedTxid);
    tip = 9995;
    keystore.locked = true;
    expect(
      await actor.reconcileSource('operation'),
      isA<Ok<void, ArkFailure>>(),
    );
    expect(_ok(await store.reservations()), isEmpty);
    expect(_ok(await store.pendingForAccount(account.canonical)), isNull);
    expect(
      (await server.requests()).counts['blockchain.transaction.broadcast'] ?? 0,
      0,
    );
  });

  test('unavailable Ark proof retains saved bytes without emission', () async {
    final signed = await persisted('signed');
    syncUnavailable = true;
    await restart();
    keystore.locked = true;
    expect(await actor.confirm(account, 'operation', token), isA<Err>());
    expect(
      (await server.requests()).counts['blockchain.transaction.broadcast'] ?? 0,
      0,
    );
    expect(_ok(await store.readBoardReview('operation')).signedPsbt, signed);
    expect(_ok(await store.reservations()), isNotEmpty);
  });

  for (final phase in ['signing', 'signed', 'broadcasting']) {
    test('saved $phase bytes recover after review TTL at six blocks', () async {
      final signed = await persisted(phase);
      await restart();
      tip = 9994;
      keystore.locked = true;
      final reads = keystore.reads;
      expect(
        await actor.confirm(account, 'operation', token),
        isA<Ok<ArkOperation, ArkFailure>>(),
      );
      final entry = _ok(await store.readBoardReview('operation'));
      expect(entry.phase, 'broadcast');
      expect(entry.signedPsbt, signed);
      expect(entry.binding.unsignedTxid, binding.unsignedTxid);
      expect(keystore.reads, reads);
      await settled();
    });

    test(
      'saved $phase bytes stay held at five blocks without emission',
      () async {
        final signed = await persisted(phase);
        await restart();
        tip = 9995;
        keystore.locked = true;
        expect(await actor.confirm(account, 'operation', token), isA<Err>());
        expect(
          (await server.requests())
                  .counts['blockchain.transaction.broadcast'] ??
              0,
          0,
        );
        expect(_ok(await store.reservations()), isNotEmpty);
        expect(
          _ok(await store.readBoardReview('operation')).signedPsbt,
          signed,
        );
        // A guarded source broadcast at an earlier safe height may already be
        // confirmed while Ark is now too close to expiry. Never reject settlement.
      },
    );
  }

  test(
    'failed finish waits for source observation before exact redelivery',
    () async {
      final signed = await persisted('signed');
      failPhase('broadcast');
      expect(await actor.confirm(account, 'operation', token), isA<Err>());
      expect(
        _ok(await store.readBoardReview('operation')).phase,
        'broadcasting',
      );
      expect(
        (await server.requests()).counts['blockchain.transaction.broadcast'],
        1,
      );
      clearFault();
      await restart();
      keystore.locked = true;
      expect(await actor.confirm(account, 'operation', token), isA<Err>());
      expect(
        (await server.requests()).counts['blockchain.transaction.broadcast'] ??
            0,
        0,
      );
      expect(_ok(await store.reservations()), isNotEmpty);
      await server.exposeBroadcasts(true);
      expect(
        await actor.confirm(account, 'operation', token),
        isA<Ok<ArkOperation, ArkFailure>>(),
      );
      expect(_ok(await store.readBoardReview('operation')).signedPsbt, signed);
      expect(_ok(await store.readBoardReview('operation')).phase, 'broadcast');
      await settled();
    },
  );
}
