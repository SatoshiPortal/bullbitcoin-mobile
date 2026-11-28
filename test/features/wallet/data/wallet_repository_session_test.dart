import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:sync/storage.dart' show SyncWalletValuesDatasource;
import 'package:bb_mobile/features/wallet/data/wallet_registrations.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/app_database.dart' show Signer;
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/storage.dart' show SecretsInventory;
import 'package:secrets/testing.dart' show FakeSecureStoragePlatform;
import 'package:sync/sync.dart' hide Wallet;
import 'package:sync/write.dart';

import '../../../support/inventory_fixture.dart';

class _Values extends Mock implements SyncWalletValuesDatasource {}

final class _Rows implements WalletRegistrations {
  final WalletMetadataModel row;

  _Rows(this.row);

  @override
  Future<WalletMetadataModel?> fetch(String id) async => row;

  @override
  Future<List<WalletMetadataModel>> fetchAll() async => [row];
}

final class _Offline implements WalletConnectionPort {
  @override
  Future<Result<T, SyncFailure>> run<T>({
    required Network network,
    required Future<Result<T, SyncFailure>> Function(WalletConnection)
    operation,
    required bool Function(SyncFailure) mayRetry,
  }) => throw StateError('A catalog read must not sync');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerFallbackValue(WalletKey(id: 'any', network: BitcoinNetwork.testnet));

  late Directory directory;
  late InventoryFixture fixture;
  late SecretsInventory inventory;
  late _Values values;
  late WalletRepository repository;

  setUp(() async {
    FakeSecureStoragePlatform().install();
    directory = await Directory.systemTemp.createTemp('wallet-session-');
    fixture = await InventoryFixture.open(directory);
    inventory = fixture.inventory;
    values = _Values();
    repository = WalletRepository(
      session: <T>(Future<T> Function() read) async =>
          switch (await inventory.readInSession(read)) {
            Ok(:final value) => value,
            Err() => throw const WalletSnapshotException(SyncStorageFailure()),
          },
      walletRegistrations: _Rows(
        WalletMetadataModel(
          networkCode: 'bitcoinTestnet',
          id: 'wpkh([aabbccdd/84h/1h/0h])',
          masterFingerprint: 'aabbccdd',
          xpubFingerprint: 'aabbccdd',
          isEncryptedVaultTested: false,
          isPhysicalBackupTested: false,
          xpub: 'public',
          externalPublicDescriptor: 'wpkh(public)',
          internalPublicDescriptor: 'wpkh(change)',
          signer: Signer.none,
          isDefault: false,
        ),
      ),
      walletValuesDatasource: values,
      synchronization: ForegroundWalletSynchronization(
        ElectrumSync(
          connections: _Offline(),
          documentsDirectory: () async => directory.path,
          readRevision: (_) async => const Err(SyncNotFoundFailure()),
        ),
      ),
      syncStarted: const Stream<String>.empty(),
      syncFinished: const Stream<String>.empty(),
    );
  });

  tearDown(() async {
    await fixture.close();
    await directory.delete(recursive: true);
  });

  for (final reopen in [false, true]) {
    test('a revoked balance join is not published (reopen: $reopen)', () async {
      final started = Completer<void>();
      final release = Completer<void>();
      when(() => values.getBalance(key: any(named: 'key')))
          .thenAnswer((_) async {
            started.complete();
            await release.future;
            return Balances(
              confirmedSat: BigInt.from(7),
              immatureSat: BigInt.zero,
              trustedPendingSat: BigInt.zero,
              untrustedPendingSat: BigInt.zero,
              spendableSat: BigInt.from(7),
              totalSat: BigInt.from(7),
            );
          });

      final result = repository.getWallets();
      await started.future;
      final locking = inventory.lock();
      if (reopen) {
        // The lock is still draining the admitted join: it cannot be reopened
        // under it.
        expect(await inventory.resumeUnprotected(), isA<Err>());
      }
      release.complete();

      expect(await result, isA<Err<List<dynamic>, WalletFailure>>());
      await locking;
      if (reopen) {
        expect(await inventory.resumeUnprotected(), isA<Ok>());
      }
    });
  }
}
