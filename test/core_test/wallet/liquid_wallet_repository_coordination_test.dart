import 'dart:async';

import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wallet_transaction_sync/wallet_transaction_sync.dart';

class _MockMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

class _MockSeedDatasource extends Mock implements SeedDatasource {}

class _MockLwkDatasource extends Mock implements LwkWalletDatasource {}

class _TrackingCoordinator implements WalletSourceOperationCoordinator {
  int acquisitions = 0;
  bool inOperation = false;

  @override
  Future<T> runExclusive<T>(
    WalletSourceKey key,
    Future<T> Function(WalletSourceSession session) operation, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    acquisitions++;
    inOperation = true;
    try {
      return await operation(_Session());
    } finally {
      inOperation = false;
    }
  }
}

class _Session implements WalletSourceSession {
  @override
  bool get isClosed => false;

  @override
  void ensureOpen() {}

  @override
  Future<void> close() async {}
}

const _walletId = 'elwpkh([73c5da0a/84h/1h/0h])';
const _otherWalletId = 'elwpkh([deadbeef/84h/1h/0h])';

WalletMetadataModel _metadata(String id) => WalletMetadataModel(
  id: id,
  masterFingerprint: '73c5da0a',
  xpubFingerprint: 'deadbeef',
  isEncryptedVaultTested: false,
  isPhysicalBackupTested: false,
  xpub: 'tpub-test',
  externalPublicDescriptor: 'elwpkh(external)',
  internalPublicDescriptor: 'elwpkh(internal)',
  signer: Signer.local,
  isDefault: false,
);

LiquidWalletRepository _repository({
  required WalletMetadataDatasource metadata,
  required SeedDatasource seed,
  required LwkWalletDatasource lwk,
  required WalletSourceOperationCoordinator coordinator,
}) => LiquidWalletRepository(
  walletMetadataDatasource: metadata,
  seedDatasource: seed,
  lwkWalletDatasource: lwk,
  coordinator: coordinator,
);

void main() {
  setUpAll(() {
    registerFallbackValue(
      const WalletModel.publicLwk(
        id: _walletId,
        combinedCtDescriptor: 'elwpkh(external)',
        isTestnet: true,
      ),
    );
    registerFallbackValue(
      const PrivateLwkWalletModel(
        id: _walletId,
        mnemonic: 'abandon',
        isTestnet: true,
      ),
    );
  });

  test('same source key serializes while a different key proceeds', () async {
    final metadata = _MockMetadataDatasource();
    final lwk = _MockLwkDatasource();
    final coordinator = InMemoryWalletSourceOperationCoordinator();
    final entered = Completer<void>();
    final secondEntered = Completer<void>();
    final release = Completer<void>();
    when(
      () => metadata.fetch(_walletId),
    ).thenAnswer((_) async => _metadata(_walletId));
    when(
      () => metadata.fetch(_otherWalletId),
    ).thenAnswer((_) async => _metadata(_otherWalletId));
    when(() => lwk.getLbtcUtxoCount(wallet: any(named: 'wallet'))).thenAnswer((
      _,
    ) async {
      if (!entered.isCompleted) {
        entered.complete();
      } else {
        secondEntered.complete();
      }
      await release.future;
      return 1;
    });
    final repository = _repository(
      metadata: metadata,
      seed: _MockSeedDatasource(),
      lwk: lwk,
      coordinator: coordinator,
    );

    final first = repository.getLbtcUtxoCount(walletId: _walletId);
    await entered.future;
    final second = repository.getLbtcUtxoCount(walletId: _walletId);
    await Future<void>.delayed(Duration.zero);
    expect(secondEntered.isCompleted, isFalse);

    release.complete();
    expect(await first, 1);
    expect(await second, 1);
  });

  test('different source keys remain independent', () async {
    final metadata = _MockMetadataDatasource();
    final lwk = _MockLwkDatasource();
    final coordinator = InMemoryWalletSourceOperationCoordinator();
    final release = Completer<void>();
    when(
      () => metadata.fetch(_walletId),
    ).thenAnswer((_) async => _metadata(_walletId));
    when(
      () => metadata.fetch(_otherWalletId),
    ).thenAnswer((_) async => _metadata(_otherWalletId));
    when(() => lwk.getLbtcUtxoCount(wallet: any(named: 'wallet'))).thenAnswer((
      invocation,
    ) async {
      final wallet = invocation.namedArguments[#wallet] as WalletModel;
      if (wallet.id == _walletId) await release.future;
      return 1;
    });
    final repository = _repository(
      metadata: metadata,
      seed: _MockSeedDatasource(),
      lwk: lwk,
      coordinator: coordinator,
    );

    final first = repository.getLbtcUtxoCount(walletId: _walletId);
    final second = repository.getLbtcUtxoCount(walletId: _otherWalletId);
    expect(await second, 1);
    release.complete();
    expect(await first, 1);
  });

  test('signing invokes the datasource inside the source gate', () async {
    final metadata = _MockMetadataDatasource();
    final seed = _MockSeedDatasource();
    final lwk = _MockLwkDatasource();
    final coordinator = _TrackingCoordinator();
    when(
      () => metadata.fetch(_walletId),
    ).thenAnswer((_) async => _metadata(_walletId));
    when(() => seed.get('73c5da0a')).thenAnswer(
      (_) async => SeedModel.fromJson(const {
        'runtimeType': 'mnemonic',
        'mnemonicWords': ['abandon'],
      }),
    );
    var datasourceCalledInsideGate = false;
    when(() => lwk.signPset(any(), wallet: any(named: 'wallet'))).thenAnswer((
      _,
    ) async {
      datasourceCalledInsideGate = coordinator.inOperation;
      return 'signed';
    });
    final repository = _repository(
      metadata: metadata,
      seed: seed,
      lwk: lwk,
      coordinator: coordinator,
    );

    expect(
      await repository.signPset(pset: 'pset', walletId: _walletId),
      'signed',
    );
    expect(datasourceCalledInsideGate, isTrue);
    expect(coordinator.acquisitions, 1);
  });

  test('pure PSET decoding does not acquire the source gate', () async {
    final lwk = _MockLwkDatasource();
    final coordinator = _TrackingCoordinator();
    when(
      () => lwk.decodeAbsoluteFeesFromPset('pset'),
    ).thenAnswer((_) async => (123, 4));
    final repository = _repository(
      metadata: _MockMetadataDatasource(),
      seed: _MockSeedDatasource(),
      lwk: lwk,
      coordinator: coordinator,
    );

    expect(await repository.getPsetSizeAndAbsoluteFees(pset: 'pset'), (123, 4));
    expect(coordinator.acquisitions, 0);
  });
}
