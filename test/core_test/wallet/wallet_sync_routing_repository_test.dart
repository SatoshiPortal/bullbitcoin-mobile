import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/cbf_wallet_sync_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/electrum_wallet_sync_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_sync_routing_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_sync_progress.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_compact_block_filters_available_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_sync_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockCheckCompactBlockFiltersAvailableUsecase extends Mock
    implements CheckCompactBlockFiltersAvailableUsecase {}

class _MockElectrumWalletSyncRepository extends Mock
    implements ElectrumWalletSyncRepository {}

class _MockCbfWalletSyncRepository extends Mock
    implements CbfWalletSyncRepository {}

WalletMetadataModel _buildMetadata({
  String id = '[abcdef12/84h/0h/0h]',
  BitcoinSyncBackend bitcoinSyncBackend = BitcoinSyncBackend.electrum,
  DateTime? syncedAt,
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
    syncedAt: syncedAt,
  );
}

SettingsEntity _buildSettings({bool useTorProxy = false}) {
  return SettingsEntity(
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'USD',
    useTorProxy: useTorProxy,
  );
}

void main() {
  late _MockWalletMetadataDatasource walletMetadataDatasource;
  late _MockSettingsRepository settingsRepository;
  late _MockCheckCompactBlockFiltersAvailableUsecase
  checkCompactBlockFiltersAvailable;
  late _MockElectrumWalletSyncRepository electrum;
  late _MockCbfWalletSyncRepository cbf;
  late WalletSyncRoutingRepository repository;

  setUp(() {
    walletMetadataDatasource = _MockWalletMetadataDatasource();
    settingsRepository = _MockSettingsRepository();
    checkCompactBlockFiltersAvailable =
        _MockCheckCompactBlockFiltersAvailableUsecase();
    electrum = _MockElectrumWalletSyncRepository();
    cbf = _MockCbfWalletSyncRepository();
    repository = WalletSyncRoutingRepository(
      walletMetadataDatasource: walletMetadataDatasource,
      settingsRepository: settingsRepository,
      checkCompactBlockFiltersAvailableUsecase:
          checkCompactBlockFiltersAvailable,
      electrumWalletSyncRepository: electrum,
      cbfWalletSyncRepository: cbf,
    );
  });

  group('WalletSyncRoutingRepository.startSync', () {
    const walletId = '[abcdef12/84h/0h/0h]';

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
      verifyNever(() => electrum.startSync(walletId: any(named: 'walletId')));
      verifyNever(() => cbf.startSync(walletId: any(named: 'walletId')));
    });

    test('an electrum-backend wallet always routes to Electrum, never '
        'touching settings or the CBF availability gate', () async {
      when(() => walletMetadataDatasource.fetch(walletId)).thenAnswer(
        (_) async => _buildMetadata(
          id: walletId,
          bitcoinSyncBackend: BitcoinSyncBackend.electrum,
        ),
      );
      when(
        () => electrum.startSync(walletId: walletId),
      ).thenAnswer((_) async => const Ok(null));

      final result = await repository.startSync(walletId: walletId);

      expect(result, isA<Ok<void, WalletSyncFailure>>());
      verify(() => electrum.startSync(walletId: walletId)).called(1);
      verifyNever(() => settingsRepository.fetch());
      verifyNever(() => checkCompactBlockFiltersAvailable.execute());
      verifyZeroInteractions(cbf);
    });

    test('a CBF-backend wallet with Tor proxy enabled -> '
        'WalletSyncTorUnsupportedFailure, without even consulting the '
        'availability usecase', () async {
      when(() => walletMetadataDatasource.fetch(walletId)).thenAnswer(
        (_) async => _buildMetadata(
          id: walletId,
          bitcoinSyncBackend: BitcoinSyncBackend.compactBlockFilters,
          syncedAt: DateTime.now().toUtc(),
        ),
      );
      when(
        () => settingsRepository.fetch(),
      ).thenAnswer((_) async => _buildSettings(useTorProxy: true));

      final result = await repository.startSync(walletId: walletId);

      expect(result, isA<Err<void, WalletSyncFailure>>());
      expect(
        (result as Err<void, WalletSyncFailure>).failure,
        isA<WalletSyncTorUnsupportedFailure>(),
      );
      verifyNever(() => checkCompactBlockFiltersAvailable.execute());
      verifyZeroInteractions(cbf);
    });

    test('a CBF-backend wallet with Tor off but the availability usecase '
        'returning false -> WalletSyncDeveloperGateClosedFailure, CBF never '
        'started', () async {
      when(() => walletMetadataDatasource.fetch(walletId)).thenAnswer(
        (_) async => _buildMetadata(
          id: walletId,
          bitcoinSyncBackend: BitcoinSyncBackend.compactBlockFilters,
          syncedAt: DateTime.now().toUtc(),
        ),
      );
      when(
        () => settingsRepository.fetch(),
      ).thenAnswer((_) async => _buildSettings());
      when(
        () => checkCompactBlockFiltersAvailable.execute(),
      ).thenAnswer((_) async => false);

      final result = await repository.startSync(walletId: walletId);

      expect(result, isA<Err<void, WalletSyncFailure>>());
      expect(
        (result as Err<void, WalletSyncFailure>).failure,
        isA<WalletSyncDeveloperGateClosedFailure>(),
      );
      verifyZeroInteractions(cbf);
    });

    test('a CBF-backend wallet with Tor off and the availability usecase '
        'returning true routes to CBF', () async {
      when(() => walletMetadataDatasource.fetch(walletId)).thenAnswer(
        (_) async => _buildMetadata(
          id: walletId,
          bitcoinSyncBackend: BitcoinSyncBackend.compactBlockFilters,
          syncedAt: DateTime.now().toUtc(),
        ),
      );
      when(
        () => settingsRepository.fetch(),
      ).thenAnswer((_) async => _buildSettings());
      when(
        () => checkCompactBlockFiltersAvailable.execute(),
      ).thenAnswer((_) async => true);
      when(
        () => cbf.startSync(walletId: walletId),
      ).thenAnswer((_) async => const Ok(null));

      final result = await repository.startSync(walletId: walletId);

      expect(result, isA<Ok<void, WalletSyncFailure>>());
      verify(() => cbf.startSync(walletId: walletId)).called(1);
      verifyNever(() => electrum.startSync(walletId: any(named: 'walletId')));
    });

    test(
      'a CBF-backend wallet with no syncedAt yet (never completed a real '
      'sync) still routes to CBF directly rather than being silently '
      'bootstrapped through Electrum first — CbfScanTypeResolver is what '
      'now keeps that first sync safe, by starting it from the wallet\'s '
      'own persisted birthday checkpoint instead of assuming SyncScanType',
      () async {
        when(() => walletMetadataDatasource.fetch(walletId)).thenAnswer(
          (_) async => _buildMetadata(
            id: walletId,
            bitcoinSyncBackend: BitcoinSyncBackend.compactBlockFilters,
          ),
        );
        when(
          () => settingsRepository.fetch(),
        ).thenAnswer((_) async => _buildSettings());
        when(
          () => checkCompactBlockFiltersAvailable.execute(),
        ).thenAnswer((_) async => true);
        when(
          () => cbf.startSync(walletId: walletId),
        ).thenAnswer((_) async => const Ok(null));

        final result = await repository.startSync(walletId: walletId);

        expect(result, isA<Ok<void, WalletSyncFailure>>());
        verify(() => cbf.startSync(walletId: walletId)).called(1);
        verifyNever(() => electrum.startSync(walletId: any(named: 'walletId')));
      },
    );
  });

  test('watchProgress merges both backends', () async {
    when(() => electrum.watchProgress()).thenAnswer(
      (_) => Stream.value(
        const WalletSyncStarted('a', BitcoinSyncBackend.electrum),
      ),
    );
    when(
      () => cbf.watchProgress(),
    ).thenAnswer((_) => Stream.value(const WalletSyncCompleted('b')));

    final events = await repository.watchProgress().toList();

    expect(events, hasLength(2));
    expect(events, contains(isA<WalletSyncStarted>()));
    expect(events, contains(isA<WalletSyncCompleted>()));
  });

  test('cancelSync forwards to both backends regardless of which one is '
      'actually running', () async {
    when(
      () => electrum.cancelSync(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async {});
    when(
      () => cbf.cancelSync(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async {});

    await repository.cancelSync(walletId: 'wallet-1');

    verify(() => electrum.cancelSync(walletId: 'wallet-1')).called(1);
    verify(() => cbf.cancelSync(walletId: 'wallet-1')).called(1);
  });
}
