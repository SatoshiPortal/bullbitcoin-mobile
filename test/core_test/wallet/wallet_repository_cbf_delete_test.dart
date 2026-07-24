import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/cbf_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/cbf_sync_activity_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

class _MockBdkWalletDatasource extends Mock implements BdkWalletDatasource {}

class _MockLwkWalletDatasource extends Mock implements LwkWalletDatasource {}

class _MockCbfWalletDatasource extends Mock implements CbfWalletDatasource {}

class _MockElectrumServersPort extends Mock implements ElectrumServersPort {}

class _MockCbfSyncActivityPort extends Mock implements CbfSyncActivityPort {}

WalletMetadataModel _buildMetadata({
  String id = '[abcdef12/84h/0h/0h]',
  BitcoinSyncBackend bitcoinSyncBackend = BitcoinSyncBackend.electrum,
}) {
  return WalletMetadataModel(
    id: id,
    masterFingerprint: 'abcdef12',
    xpubFingerprint: '12345678',
    isEncryptedVaultTested: false,
    isPhysicalBackupTested: false,
    xpub: 'xpub-fake',
    externalPublicDescriptor: 'wpkh([abcdef12/84h/0h/0h]xpub-fake/0/*)',
    internalPublicDescriptor: 'wpkh([abcdef12/84h/0h/0h]xpub-fake/1/*)',
    signer: Signer.local,
    isDefault: false,
    bitcoinSyncBackend: bitcoinSyncBackend,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_buildMetadata());
    registerFallbackValue(WalletModel.fromMetadata(_buildMetadata()));
  });

  late _MockWalletMetadataDatasource walletMetadataDatasource;
  late _MockBdkWalletDatasource bdkWalletDatasource;
  late _MockLwkWalletDatasource lwkWalletDatasource;
  late _MockCbfWalletDatasource cbfWalletDatasource;
  late _MockElectrumServersPort serversPort;
  late _MockCbfSyncActivityPort cbfSyncActivityPort;
  late WalletRepository repository;

  const walletId = '[abcdef12/84h/0h/0h]';

  setUp(() {
    walletMetadataDatasource = _MockWalletMetadataDatasource();
    bdkWalletDatasource = _MockBdkWalletDatasource();
    lwkWalletDatasource = _MockLwkWalletDatasource();
    cbfWalletDatasource = _MockCbfWalletDatasource();
    serversPort = _MockElectrumServersPort();
    cbfSyncActivityPort = _MockCbfSyncActivityPort();

    // WalletRepository's constructor subscribes to these on both
    // datasources; stub before construction so `new WalletRepository`
    // itself does not throw.
    when(
      () => bdkWalletDatasource.walletSyncStartedStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => bdkWalletDatasource.walletSyncFinishedStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => lwkWalletDatasource.walletSyncStartedStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => lwkWalletDatasource.walletSyncFinishedStream,
    ).thenAnswer((_) => const Stream.empty());

    repository = WalletRepository(
      walletMetadataDatasource: walletMetadataDatasource,
      bdkWalletDatasource: bdkWalletDatasource,
      lwkWalletDatasource: lwkWalletDatasource,
      cbfWalletDatasource: cbfWalletDatasource,
      serversPort: serversPort,
      cbfSyncActivityPort: cbfSyncActivityPort,
    );

    // Every existing test in this file exercises the "no active session"
    // path — see the dedicated group below for the blocked-deletion guard
    // itself.
    when(
      () => cbfSyncActivityPort.isActive(walletId: any(named: 'walletId')),
    ).thenReturn(false);
    when(
      () => cbfWalletDatasource.cancelAndWait(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async {});
    when(
      () => bdkWalletDatasource.delete(wallet: any(named: 'wallet')),
    ).thenAnswer((_) async {});
    when(
      () => cbfWalletDatasource.deleteDataDir(metadata: any(named: 'metadata')),
    ).thenAnswer((_) async {});
    when(
      () => walletMetadataDatasource.delete(walletId),
    ).thenAnswer((_) async {});
  });

  test(
    'deletes the CBF dataDir for a Bitcoin wallet on the CBF backend',
    () async {
      when(() => walletMetadataDatasource.fetch(walletId)).thenAnswer(
        (_) async => _buildMetadata(
          id: walletId,
          bitcoinSyncBackend: BitcoinSyncBackend.compactBlockFilters,
        ),
      );

      await repository.deleteWallet(walletId: walletId);

      verify(
        () =>
            cbfWalletDatasource.deleteDataDir(metadata: any(named: 'metadata')),
      ).called(1);
    },
  );

  test('deletes the CBF dataDir for a Bitcoin wallet even after it switched to '
      'the Electrum backend — a wallet that previously ran on CBF and later '
      'switched away can still have a leftover dataDir on disk that must not '
      'survive deletion', () async {
    when(() => walletMetadataDatasource.fetch(walletId)).thenAnswer(
      (_) async => _buildMetadata(
        id: walletId,
        bitcoinSyncBackend: BitcoinSyncBackend.electrum,
      ),
    );

    await repository.deleteWallet(walletId: walletId);

    verify(
      () => cbfWalletDatasource.deleteDataDir(metadata: any(named: 'metadata')),
    ).called(1);
    // Only a CBF backend can have an active native session, so neither
    // of these is expected for a wallet currently on Electrum.
    verifyNever(
      () => cbfWalletDatasource.cancelAndWait(walletId: any(named: 'walletId')),
    );
  });

  test(
    'still deletes the wallet metadata even if CBF dataDir cleanup throws',
    () async {
      when(() => walletMetadataDatasource.fetch(walletId)).thenAnswer(
        (_) async => _buildMetadata(
          id: walletId,
          bitcoinSyncBackend: BitcoinSyncBackend.compactBlockFilters,
        ),
      );
      when(
        () =>
            cbfWalletDatasource.deleteDataDir(metadata: any(named: 'metadata')),
      ).thenThrow(Exception('disk error'));

      await repository.deleteWallet(walletId: walletId);

      verify(() => walletMetadataDatasource.delete(walletId)).called(1);
    },
  );

  test('cancels and awaits the CBF session before deleting the BDK db or the '
      'CBF dataDir, for a wallet on the CBF backend', () async {
    when(() => walletMetadataDatasource.fetch(walletId)).thenAnswer(
      (_) async => _buildMetadata(
        id: walletId,
        bitcoinSyncBackend: BitcoinSyncBackend.compactBlockFilters,
      ),
    );

    await repository.deleteWallet(walletId: walletId);

    verifyInOrder([
      () => cbfWalletDatasource.cancelAndWait(walletId: walletId),
      () => bdkWalletDatasource.delete(wallet: any(named: 'wallet')),
      () => cbfWalletDatasource.deleteDataDir(metadata: any(named: 'metadata')),
    ]);
  });

  test(
    'does not call cancelAndWait for a Bitcoin wallet on the Electrum '
    'backend — only a CBF backend can have an active native session',
    () async {
      when(() => walletMetadataDatasource.fetch(walletId)).thenAnswer(
        (_) async => _buildMetadata(
          id: walletId,
          bitcoinSyncBackend: BitcoinSyncBackend.electrum,
        ),
      );

      await repository.deleteWallet(walletId: walletId);

      verifyNever(
        () =>
            cbfWalletDatasource.cancelAndWait(walletId: any(named: 'walletId')),
      );
    },
  );

  test('a cancelAndWait timeout aborts deletion entirely — never deletes the '
      'BDK db, the CBF dataDir, or the wallet metadata', () async {
    when(() => walletMetadataDatasource.fetch(walletId)).thenAnswer(
      (_) async => _buildMetadata(
        id: walletId,
        bitcoinSyncBackend: BitcoinSyncBackend.compactBlockFilters,
      ),
    );
    when(
      () => cbfWalletDatasource.cancelAndWait(walletId: any(named: 'walletId')),
    ).thenThrow(CbfSessionTeardownTimeoutException('timed out'));

    await expectLater(
      repository.deleteWallet(walletId: walletId),
      throwsA(isA<CbfSessionTeardownTimeoutException>()),
    );

    verifyNever(() => bdkWalletDatasource.delete(wallet: any(named: 'wallet')));
    verifyNever(
      () => cbfWalletDatasource.deleteDataDir(metadata: any(named: 'metadata')),
    );
    verifyNever(() => walletMetadataDatasource.delete(walletId));
  });

  group('active CBF session — blocked, never a shutdown', () {
    test('refuses deletion with a typed failure when the CBF session is '
        'currently active, without ever calling cancelAndWait', () async {
      when(() => walletMetadataDatasource.fetch(walletId)).thenAnswer(
        (_) async => _buildMetadata(
          id: walletId,
          bitcoinSyncBackend: BitcoinSyncBackend.compactBlockFilters,
        ),
      );
      when(
        () => cbfSyncActivityPort.isActive(walletId: walletId),
      ).thenReturn(true);

      await expectLater(
        repository.deleteWallet(walletId: walletId),
        throwsA(isA<CannotDeleteWalletWithActiveCbfSyncError>()),
      );

      verifyNever(
        () =>
            cbfWalletDatasource.cancelAndWait(walletId: any(named: 'walletId')),
      );
      verifyNever(
        () => bdkWalletDatasource.delete(wallet: any(named: 'wallet')),
      );
      verifyNever(
        () =>
            cbfWalletDatasource.deleteDataDir(metadata: any(named: 'metadata')),
      );
      verifyNever(() => walletMetadataDatasource.delete(walletId));
    });

    test(
      'never consults CBF activity for a Bitcoin wallet on the Electrum '
      'backend — only a CBF backend can have an active native session',
      () async {
        when(() => walletMetadataDatasource.fetch(walletId)).thenAnswer(
          (_) async => _buildMetadata(
            id: walletId,
            bitcoinSyncBackend: BitcoinSyncBackend.electrum,
          ),
        );

        await repository.deleteWallet(walletId: walletId);

        verifyNever(
          () => cbfSyncActivityPort.isActive(walletId: any(named: 'walletId')),
        );
      },
    );

    test('proceeds with deletion when the CBF session is not active', () async {
      when(() => walletMetadataDatasource.fetch(walletId)).thenAnswer(
        (_) async => _buildMetadata(
          id: walletId,
          bitcoinSyncBackend: BitcoinSyncBackend.compactBlockFilters,
        ),
      );
      when(
        () => cbfSyncActivityPort.isActive(walletId: walletId),
      ).thenReturn(false);

      await repository.deleteWallet(walletId: walletId);

      verify(() => walletMetadataDatasource.delete(walletId)).called(1);
    });
  });
}
