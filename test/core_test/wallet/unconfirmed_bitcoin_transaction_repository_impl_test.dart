import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/cbf_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/unconfirmed_bitcoin_transaction_repository_impl.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_sync_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

class _MockCbfWalletDatasource extends Mock implements CbfWalletDatasource {}

class _MockBdkWalletDatasource extends Mock implements BdkWalletDatasource {}

WalletMetadataModel _buildMetadata({
  String id = '[abcdef12/84h/0h/0h]',
  BitcoinSyncBackend bitcoinSyncBackend =
      BitcoinSyncBackend.compactBlockFilters,
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
    registerFallbackValue(
      WalletModel.publicBdk(
        id: 'fallback',
        externalDescriptor: 'fallback-external',
        internalDescriptor: 'fallback-internal',
        isTestnet: false,
      ),
    );
    registerFallbackValue(_buildMetadata());
  });

  late _MockWalletMetadataDatasource walletMetadataDatasource;
  late _MockCbfWalletDatasource cbfWalletDatasource;
  late _MockBdkWalletDatasource bdkWalletDatasource;
  late UnconfirmedBitcoinTransactionRepositoryImpl repository;

  const walletId = 'wallet-1';

  void verifyNoBdkCall() {
    verifyNever(
      () => bdkWalletDatasource.applyUnconfirmedTransaction(
        wallet: any(named: 'wallet'),
        transaction: any(named: 'transaction'),
        isPsbt: any(named: 'isPsbt'),
        lastSeen: any(named: 'lastSeen'),
      ),
    );
  }

  setUp(() {
    walletMetadataDatasource = _MockWalletMetadataDatasource();
    cbfWalletDatasource = _MockCbfWalletDatasource();
    bdkWalletDatasource = _MockBdkWalletDatasource();
    repository = UnconfirmedBitcoinTransactionRepositoryImpl(
      walletMetadataDatasource: walletMetadataDatasource,
      cbfWalletDatasource: cbfWalletDatasource,
      bdkWalletDatasource: bdkWalletDatasource,
    );
    // Defaults to "no active session" so every existing (fallback-path)
    // test below is unaffected unless it explicitly overrides this.
    when(
      () => cbfWalletDatasource.applyUnconfirmedTransactionIfActive(
        metadata: any(named: 'metadata'),
        transaction: any(named: 'transaction'),
        isPsbt: any(named: 'isPsbt'),
      ),
    ).thenAnswer((_) async => false);
  });

  group('record — routing', () {
    test('missing wallet metadata -> Err(WalletSyncWalletNotFoundFailure), '
        'no BDK call', () async {
      when(
        () => walletMetadataDatasource.fetch(walletId),
      ).thenAnswer((_) async => null);

      final result = await repository.record(
        walletId: walletId,
        transaction: 'psbt',
        isPsbt: true,
      );

      expect(result, isA<Err<void, WalletSyncFailure>>());
      expect(
        (result as Err<void, WalletSyncFailure>).failure,
        isA<WalletSyncWalletNotFoundFailure>(),
      );
      verifyNoBdkCall();
    });

    test('liquid wallet -> no-op Ok, no BDK call', () async {
      final metadata = _buildMetadata(
        id: 'elwpkh([abcdef12/84h/1776h/0h]xpub-fake/0/*)',
      );
      when(
        () => walletMetadataDatasource.fetch(walletId),
      ).thenAnswer((_) async => metadata);

      final result = await repository.record(
        walletId: walletId,
        transaction: 'psbt',
        isPsbt: true,
      );

      expect(result, isA<Ok<void, WalletSyncFailure>>());
      verifyNoBdkCall();
    });

    test('Electrum-backend Bitcoin wallet -> no-op Ok, no BDK call', () async {
      final metadata = _buildMetadata(
        bitcoinSyncBackend: BitcoinSyncBackend.electrum,
      );
      when(
        () => walletMetadataDatasource.fetch(walletId),
      ).thenAnswer((_) async => metadata);

      final result = await repository.record(
        walletId: walletId,
        transaction: 'psbt',
        isPsbt: true,
      );

      expect(result, isA<Ok<void, WalletSyncFailure>>());
      verifyNoBdkCall();
    });
  });

  group('record — CBF wallet', () {
    test('applies the unconfirmed transaction to the public BDK wallet built '
        'from the metadata, and persists it', () async {
      final metadata = _buildMetadata();
      when(
        () => walletMetadataDatasource.fetch(walletId),
      ).thenAnswer((_) async => metadata);
      when(
        () => bdkWalletDatasource.applyUnconfirmedTransaction(
          wallet: any(named: 'wallet'),
          transaction: any(named: 'transaction'),
          isPsbt: any(named: 'isPsbt'),
          lastSeen: any(named: 'lastSeen'),
        ),
      ).thenAnswer((_) async {});

      final beforeSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final result = await repository.record(
        walletId: walletId,
        transaction: 'signed-psbt',
        isPsbt: true,
      );
      final afterSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      expect(result, isA<Ok<void, WalletSyncFailure>>());
      final captured = verify(
        () => bdkWalletDatasource.applyUnconfirmedTransaction(
          wallet: captureAny(named: 'wallet'),
          transaction: captureAny(named: 'transaction'),
          isPsbt: captureAny(named: 'isPsbt'),
          lastSeen: captureAny(named: 'lastSeen'),
        ),
      ).captured;

      expect(captured[0], WalletModel.fromMetadata(metadata));
      expect(captured[1], 'signed-psbt');
      expect(captured[2], true);
      final lastSeen = captured[3] as int;
      expect(lastSeen, inInclusiveRange(beforeSec, afterSec));
    });

    test('a BDK failure maps to Err(WalletSyncCbfFailure) — raw error text is '
        'never surfaced', () async {
      final metadata = _buildMetadata();
      when(
        () => walletMetadataDatasource.fetch(walletId),
      ).thenAnswer((_) async => metadata);
      when(
        () => bdkWalletDatasource.applyUnconfirmedTransaction(
          wallet: any(named: 'wallet'),
          transaction: any(named: 'transaction'),
          isPsbt: any(named: 'isPsbt'),
          lastSeen: any(named: 'lastSeen'),
        ),
      ).thenThrow(Exception('some sensitive raw bdk error text'));

      final result = await repository.record(
        walletId: walletId,
        transaction: 'bad-psbt',
        isPsbt: true,
      );

      expect(result, isA<Err<void, WalletSyncFailure>>());
      final failure = (result as Err<void, WalletSyncFailure>).failure;
      expect(failure, isA<WalletSyncCbfFailure>());
      expect(
        (failure as WalletSyncCbfFailure).logMessage,
        isNot(contains('sensitive raw bdk error text')),
      );
    });
  });

  group('record — active CBF session fast path', () {
    test('applies via the active session and never falls back to '
        'BdkWalletDatasource', () async {
      final metadata = _buildMetadata();
      when(
        () => walletMetadataDatasource.fetch(walletId),
      ).thenAnswer((_) async => metadata);
      when(
        () => cbfWalletDatasource.applyUnconfirmedTransactionIfActive(
          metadata: metadata,
          transaction: 'signed-psbt',
          isPsbt: true,
        ),
      ).thenAnswer((_) async => true);

      final result = await repository.record(
        walletId: walletId,
        transaction: 'signed-psbt',
        isPsbt: true,
      );

      expect(result, isA<Ok<void, WalletSyncFailure>>());
      verify(
        () => cbfWalletDatasource.applyUnconfirmedTransactionIfActive(
          metadata: metadata,
          transaction: 'signed-psbt',
          isPsbt: true,
        ),
      ).called(1);
      verifyNoBdkCall();
    });

    test('a fast-path failure maps to Err(WalletSyncCbfFailure) without ever '
        'falling back to BdkWalletDatasource', () async {
      final metadata = _buildMetadata();
      when(
        () => walletMetadataDatasource.fetch(walletId),
      ).thenAnswer((_) async => metadata);
      when(
        () => cbfWalletDatasource.applyUnconfirmedTransactionIfActive(
          metadata: any(named: 'metadata'),
          transaction: any(named: 'transaction'),
          isPsbt: any(named: 'isPsbt'),
        ),
      ).thenThrow(Exception('some sensitive raw error text'));

      final result = await repository.record(
        walletId: walletId,
        transaction: 'signed-psbt',
        isPsbt: true,
      );

      expect(result, isA<Err<void, WalletSyncFailure>>());
      expect(
        (result as Err<void, WalletSyncFailure>).failure,
        isA<WalletSyncCbfFailure>(),
      );
      verifyNoBdkCall();
    });
  });
}
