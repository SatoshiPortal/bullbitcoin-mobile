import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/cbf_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/cbf_wallet_sync_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_sync_progress.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_sync_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

class _MockCbfWalletDatasource extends Mock implements CbfWalletDatasource {}

WalletMetadataModel _buildMetadata({String id = '[abcdef12/84h/0h/0h]'}) {
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
    bitcoinSyncBackend: BitcoinSyncBackend.compactBlockFilters,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_buildMetadata());
  });

  late _MockWalletMetadataDatasource walletMetadataDatasource;
  late _MockCbfWalletDatasource cbfWalletDatasource;
  late CbfWalletSyncRepository repository;

  setUp(() {
    walletMetadataDatasource = _MockWalletMetadataDatasource();
    cbfWalletDatasource = _MockCbfWalletDatasource();
    repository = CbfWalletSyncRepository(
      walletMetadataDatasource: walletMetadataDatasource,
      cbfWalletDatasource: cbfWalletDatasource,
    );
  });

  group('CbfWalletSyncRepository.startSync', () {
    const walletId = 'wallet-1';

    test('wallet not found -> WalletSyncWalletNotFoundFailure', () async {
      when(
        () => walletMetadataDatasource.fetch(walletId),
      ).thenAnswer((_) async => null);

      final result = await repository.startSync(walletId: walletId);

      expect(result, isA<Err<void, WalletSyncFailure>>());
      expect(
        (result as Err<void, WalletSyncFailure>).failure,
        isA<WalletSyncWalletNotFoundFailure>(),
      );
      verifyNever(
        () => cbfWalletDatasource.startSync(metadata: any(named: 'metadata')),
      );
    });

    test('delegates to CbfWalletDatasource.startSync with the fetched '
        'metadata', () async {
      final metadata = _buildMetadata(id: walletId);
      when(
        () => walletMetadataDatasource.fetch(walletId),
      ).thenAnswer((_) async => metadata);
      when(
        () => cbfWalletDatasource.startSync(metadata: metadata),
      ).thenAnswer((_) async => const Ok(CbfSyncOutcome.completed));
      when(
        () => walletMetadataDatasource.store(any()),
      ).thenAnswer((_) async {});

      final result = await repository.startSync(walletId: walletId);

      expect(result, isA<Ok<void, WalletSyncFailure>>());
      verify(() => cbfWalletDatasource.startSync(metadata: metadata)).called(1);
    });

    test('a genuine completion persists metadata.syncedAt (UTC)', () async {
      final metadata = _buildMetadata(id: walletId);
      when(
        () => walletMetadataDatasource.fetch(walletId),
      ).thenAnswer((_) async => metadata);
      when(
        () => cbfWalletDatasource.startSync(metadata: metadata),
      ).thenAnswer((_) async => const Ok(CbfSyncOutcome.completed));
      when(
        () => walletMetadataDatasource.store(any()),
      ).thenAnswer((_) async {});

      final beforeUtc = DateTime.now().toUtc();
      final result = await repository.startSync(walletId: walletId);
      final afterUtc = DateTime.now().toUtc();

      expect(result, isA<Ok<void, WalletSyncFailure>>());
      final stored =
          verify(
                () => walletMetadataDatasource.store(captureAny()),
              ).captured.single
              as WalletMetadataModel;
      expect(stored.syncedAt, isNotNull);
      expect(stored.syncedAt!.isUtc, isTrue);
      expect(
        stored.syncedAt!.isAfter(
              beforeUtc.subtract(const Duration(seconds: 1)),
            ) &&
            stored.syncedAt!.isBefore(afterUtc.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('a cancelled attempt does not persist syncedAt — cancellation is '
        'never recorded as a successful sync', () async {
      final metadata = _buildMetadata(id: walletId);
      when(
        () => walletMetadataDatasource.fetch(walletId),
      ).thenAnswer((_) async => metadata);
      when(
        () => cbfWalletDatasource.startSync(metadata: metadata),
      ).thenAnswer((_) async => const Ok(CbfSyncOutcome.cancelled));

      final result = await repository.startSync(walletId: walletId);

      expect(result, isA<Ok<void, WalletSyncFailure>>());
      verifyNever(() => walletMetadataDatasource.store(any()));
    });

    test('a CBF failure is forwarded and never persists syncedAt', () async {
      final metadata = _buildMetadata(id: walletId);
      when(
        () => walletMetadataDatasource.fetch(walletId),
      ).thenAnswer((_) async => metadata);
      when(() => cbfWalletDatasource.startSync(metadata: metadata)).thenAnswer(
        (_) async => const Err(WalletSyncCbfFailure('SomeException')),
      );

      final result = await repository.startSync(walletId: walletId);

      expect(result, isA<Err<void, WalletSyncFailure>>());
      expect(
        (result as Err<void, WalletSyncFailure>).failure,
        isA<WalletSyncCbfFailure>(),
      );
      verifyNever(() => walletMetadataDatasource.store(any()));
    });
  });

  test('watchProgress forwards CbfWalletDatasource.watchProgress', () async {
    final controller = Stream<WalletSyncProgress>.fromIterable([
      const WalletSyncStarted(
        'wallet-1',
        BitcoinSyncBackend.compactBlockFilters,
      ),
    ]);
    when(
      () => cbfWalletDatasource.watchProgress(),
    ).thenAnswer((_) => controller);

    final events = await repository.watchProgress().toList();

    expect(events, [isA<WalletSyncStarted>()]);
  });

  test('cancelSync forwards to CbfWalletDatasource.cancelSync', () async {
    when(
      () => cbfWalletDatasource.cancelSync(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async {});

    await repository.cancelSync(walletId: 'wallet-1');

    verify(
      () => cbfWalletDatasource.cancelSync(walletId: 'wallet-1'),
    ).called(1);
  });
}
