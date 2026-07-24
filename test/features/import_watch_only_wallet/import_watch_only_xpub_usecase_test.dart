import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_birthday_checkpoint.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_compact_block_filters_available_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/resolve_wallet_birthday_checkpoint_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_birthday_checkpoint_failure.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/import_watch_only_failure.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_xpub_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:satoshifier/satoshifier.dart' as satoshifier;

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockCheckCompactBlockFiltersAvailableUsecase extends Mock
    implements CheckCompactBlockFiltersAvailableUsecase {}

class _MockResolveWalletBirthdayCheckpointUsecase extends Mock
    implements ResolveWalletBirthdayCheckpointUsecase {}

class _MockWallet extends Mock implements Wallet {}

SettingsEntity _buildSettings({bool useCompactBlockFiltersByDefault = false}) {
  return SettingsEntity(
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'USD',
    useCompactBlockFiltersByDefault: useCompactBlockFiltersByDefault,
  );
}

void main() {
  late _MockWalletRepository repository;
  late _MockSettingsRepository settingsRepository;
  late _MockCheckCompactBlockFiltersAvailableUsecase
  checkCompactBlockFiltersAvailable;
  late _MockResolveWalletBirthdayCheckpointUsecase
  resolveWalletBirthdayCheckpoint;
  late ImportWatchOnlyXpubUsecase usecase;
  late WatchOnlyXpubEntity entity;

  final fakeCheckpoint = WalletBirthdayCheckpoint(
    requestedBirthday: DateTime.utc(2026),
    blockTimestamp: DateTime.utc(2026),
    blockHeight: 900000,
    blockHash: 'a' * 64,
  );

  setUpAll(() {
    registerFallbackValue(Network.bitcoinMainnet);
    registerFallbackValue(ScriptType.bip84);
    registerFallbackValue(BitcoinSyncBackend.electrum);
    registerFallbackValue(WalletBirthdayLookupMode.recovery);
  });

  setUp(() {
    repository = _MockWalletRepository();
    settingsRepository = _MockSettingsRepository();
    checkCompactBlockFiltersAvailable =
        _MockCheckCompactBlockFiltersAvailableUsecase();
    resolveWalletBirthdayCheckpoint =
        _MockResolveWalletBirthdayCheckpointUsecase();
    usecase = ImportWatchOnlyXpubUsecase(
      walletRepository: repository,
      settingsRepository: settingsRepository,
      checkCompactBlockFiltersAvailableUsecase:
          checkCompactBlockFiltersAvailable,
      resolveWalletBirthdayCheckpointUsecase: resolveWalletBirthdayCheckpoint,
    );
    final extendedPubkey = satoshifier.ExtendedPubkey(
      pubkey: List<int>.filled(78, 0),
      derivation: satoshifier.Derivation.bip84,
      network: satoshifier.Network.bitcoinMainnet,
    );
    entity =
        WatchOnlyWalletEntity.xpub(
              watchOnlyXpub: satoshifier.WatchOnlyXpub(
                extendedPubkey: extendedPubkey,
              ),
              label: 'My xpub wallet',
            )
            as WatchOnlyXpubEntity;

    when(
      () => settingsRepository.fetch(),
    ).thenAnswer((_) async => _buildSettings());
    when(
      () => resolveWalletBirthdayCheckpoint.execute(
        requestedBirthday: any(named: 'requestedBirthday'),
        isTestnet: any(named: 'isTestnet'),
        lookupMode: any(named: 'lookupMode'),
      ),
    ).thenAnswer((_) async => Ok(fakeCheckpoint));
  });

  group('ImportWatchOnlyXpubUsecase', () {
    test('maps a foreign repository failure to ImportFailedFailure '
        'without leaking the raw exception', () async {
      when(
        () => repository.importWatchOnlyXpub(
          xpub: any(named: 'xpub'),
          network: any(named: 'network'),
          scriptType: any(named: 'scriptType'),
          label: any(named: 'label'),
          bitcoinSyncBackend: any(named: 'bitcoinSyncBackend'),
        ),
      ).thenThrow(Exception('BDK: invalid xpub checksum 0xdeadbeef'));

      final result = await usecase.execute(watchOnlyXpub: entity);

      expect(result, isA<Err<Wallet, ImportWatchOnlyFailure>>());
      final failure = (result as Err<Wallet, ImportWatchOnlyFailure>).failure;
      expect(failure, isA<ImportFailedFailure>());
      // The sanitized failure carries no raw reason for the UI to render.
      expect(failure.logMessage, isNull);
    });

    test('returns Ok with the wallet on success', () async {
      final wallet = _MockWallet();
      when(
        () => repository.importWatchOnlyXpub(
          xpub: any(named: 'xpub'),
          network: any(named: 'network'),
          scriptType: any(named: 'scriptType'),
          label: any(named: 'label'),
          bitcoinSyncBackend: any(named: 'bitcoinSyncBackend'),
        ),
      ).thenAnswer((_) async => wallet);

      final result = await usecase.execute(watchOnlyXpub: entity);

      expect(result, isA<Ok<Wallet, ImportWatchOnlyFailure>>());
      expect(
        (result as Ok<Wallet, ImportWatchOnlyFailure>).value,
        same(wallet),
      );
    });

    test('requests compactBlockFilters when the preference is on and CBF is '
        'available', () async {
      when(() => settingsRepository.fetch()).thenAnswer(
        (_) async => _buildSettings(useCompactBlockFiltersByDefault: true),
      );
      when(
        () => checkCompactBlockFiltersAvailable.execute(),
      ).thenAnswer((_) async => true);
      when(
        () => repository.importWatchOnlyXpub(
          xpub: any(named: 'xpub'),
          network: any(named: 'network'),
          scriptType: any(named: 'scriptType'),
          label: any(named: 'label'),
          bitcoinSyncBackend: any(named: 'bitcoinSyncBackend'),
          birthdayCheckpoint: any(named: 'birthdayCheckpoint'),
        ),
      ).thenAnswer((_) async => _MockWallet());

      final result = await usecase.execute(watchOnlyXpub: entity);

      expect(result, isA<Ok<Wallet, ImportWatchOnlyFailure>>());
      verify(
        () => repository.importWatchOnlyXpub(
          xpub: any(named: 'xpub'),
          network: any(named: 'network'),
          scriptType: any(named: 'scriptType'),
          label: any(named: 'label'),
          bitcoinSyncBackend: BitcoinSyncBackend.compactBlockFilters,
          birthdayCheckpoint: fakeCheckpoint,
        ),
      ).called(1);
    });

    test('falls back to electrum when CBF is unavailable (developer mode off, '
        'a production build without ENABLE_CBF, or Tor enabled), even with '
        'the preference on', () async {
      when(() => settingsRepository.fetch()).thenAnswer(
        (_) async => _buildSettings(useCompactBlockFiltersByDefault: true),
      );
      when(
        () => checkCompactBlockFiltersAvailable.execute(),
      ).thenAnswer((_) async => false);
      when(
        () => repository.importWatchOnlyXpub(
          xpub: any(named: 'xpub'),
          network: any(named: 'network'),
          scriptType: any(named: 'scriptType'),
          label: any(named: 'label'),
          bitcoinSyncBackend: any(named: 'bitcoinSyncBackend'),
        ),
      ).thenAnswer((_) async => _MockWallet());

      final result = await usecase.execute(watchOnlyXpub: entity);

      expect(result, isA<Ok<Wallet, ImportWatchOnlyFailure>>());
      verify(
        () => repository.importWatchOnlyXpub(
          xpub: any(named: 'xpub'),
          network: any(named: 'network'),
          scriptType: any(named: 'scriptType'),
          label: any(named: 'label'),
          bitcoinSyncBackend: BitcoinSyncBackend.electrum,
        ),
      ).called(1);
    });

    test('falls back to electrum when the preference is off — the '
        'availability usecase is never even consulted', () async {
      when(() => settingsRepository.fetch()).thenAnswer(
        (_) async => _buildSettings(useCompactBlockFiltersByDefault: false),
      );
      when(
        () => repository.importWatchOnlyXpub(
          xpub: any(named: 'xpub'),
          network: any(named: 'network'),
          scriptType: any(named: 'scriptType'),
          label: any(named: 'label'),
          bitcoinSyncBackend: any(named: 'bitcoinSyncBackend'),
        ),
      ).thenAnswer((_) async => _MockWallet());

      final result = await usecase.execute(watchOnlyXpub: entity);

      expect(result, isA<Ok<Wallet, ImportWatchOnlyFailure>>());
      verify(
        () => repository.importWatchOnlyXpub(
          xpub: any(named: 'xpub'),
          network: any(named: 'network'),
          scriptType: any(named: 'scriptType'),
          label: any(named: 'label'),
          bitcoinSyncBackend: BitcoinSyncBackend.electrum,
        ),
      ).called(1);
      verifyNever(() => checkCompactBlockFiltersAvailable.execute());
    });

    test(
      'an explicit requestedSyncBackend overrides the global preference',
      () async {
        when(
          () => checkCompactBlockFiltersAvailable.execute(),
        ).thenAnswer((_) async => true);
        when(
          () => repository.importWatchOnlyXpub(
            xpub: any(named: 'xpub'),
            network: any(named: 'network'),
            scriptType: any(named: 'scriptType'),
            label: any(named: 'label'),
            bitcoinSyncBackend: any(named: 'bitcoinSyncBackend'),
            birthdayCheckpoint: any(named: 'birthdayCheckpoint'),
          ),
        ).thenAnswer((_) async => _MockWallet());

        final result = await usecase.execute(
          watchOnlyXpub: entity,
          requestedSyncBackend: BitcoinSyncBackend.compactBlockFilters,
        );

        expect(result, isA<Ok<Wallet, ImportWatchOnlyFailure>>());
        verify(
          () => repository.importWatchOnlyXpub(
            xpub: any(named: 'xpub'),
            network: any(named: 'network'),
            scriptType: any(named: 'scriptType'),
            label: any(named: 'label'),
            bitcoinSyncBackend: BitcoinSyncBackend.compactBlockFilters,
            birthdayCheckpoint: fakeCheckpoint,
          ),
        ).called(1);
      },
    );

    test('forwards a custom birthday to the resolver in recovery mode when '
        'compact block filters is selected', () async {
      when(
        () => checkCompactBlockFiltersAvailable.execute(),
      ).thenAnswer((_) async => true);
      when(
        () => repository.importWatchOnlyXpub(
          xpub: any(named: 'xpub'),
          network: any(named: 'network'),
          scriptType: any(named: 'scriptType'),
          label: any(named: 'label'),
          bitcoinSyncBackend: any(named: 'bitcoinSyncBackend'),
          birthdayCheckpoint: any(named: 'birthdayCheckpoint'),
        ),
      ).thenAnswer((_) async => _MockWallet());
      final requestedBirthday = DateTime.utc(2022, 6, 1);

      final result = await usecase.execute(
        watchOnlyXpub: entity,
        requestedSyncBackend: BitcoinSyncBackend.compactBlockFilters,
        birthday: requestedBirthday,
      );

      expect(result, isA<Ok<Wallet, ImportWatchOnlyFailure>>());
      verify(
        () => resolveWalletBirthdayCheckpoint.execute(
          requestedBirthday: requestedBirthday,
          isTestnet: false,
          lookupMode: WalletBirthdayLookupMode.recovery,
        ),
      ).called(1);
    });

    test('returns Err(BirthdayCheckpointFailure) when the resolver fails, '
        'without importing the wallet', () async {
      when(
        () => checkCompactBlockFiltersAvailable.execute(),
      ).thenAnswer((_) async => true);
      when(
        () => resolveWalletBirthdayCheckpoint.execute(
          requestedBirthday: any(named: 'requestedBirthday'),
          isTestnet: any(named: 'isTestnet'),
          lookupMode: any(named: 'lookupMode'),
        ),
      ).thenAnswer(
        (_) async => const Err(WalletBirthdayCheckpointLookupFailure('boom')),
      );

      final result = await usecase.execute(
        watchOnlyXpub: entity,
        requestedSyncBackend: BitcoinSyncBackend.compactBlockFilters,
      );

      expect(result, isA<Err<Wallet, ImportWatchOnlyFailure>>());
      expect(
        (result as Err<Wallet, ImportWatchOnlyFailure>).failure,
        isA<BirthdayCheckpointFailure>(),
      );
      verifyNever(
        () => repository.importWatchOnlyXpub(
          xpub: any(named: 'xpub'),
          network: any(named: 'network'),
          scriptType: any(named: 'scriptType'),
          label: any(named: 'label'),
          bitcoinSyncBackend: any(named: 'bitcoinSyncBackend'),
        ),
      );
    });
  });
}
