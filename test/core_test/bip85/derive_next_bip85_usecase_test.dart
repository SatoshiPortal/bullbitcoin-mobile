import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/core/seed/domain/seed_failure.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/derive_next_bip85_hex_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/derive_next_bip85_mnemonic_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/bip85/domain/fetch_all_bip85_derivations_with_entropy_usecase.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBip85Repository extends Mock implements Bip85Repository {}

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockSeedRepository extends Mock implements SeedRepository {}

class _MockGetDefaultSeedUsecase extends Mock
    implements GetDefaultSeedUsecase {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

final _fakeWallet = Wallet(
  origin: 'test-id',
  label: 'Test',
  network: Network.bitcoinMainnet,
  isDefault: true,
  masterFingerprint: 'abcd1234',
  xpubFingerprint: 'abcd1234',
  scriptType: ScriptType.bip84,
  xpub: 'xpub',
  externalPublicDescriptor: 'desc',
  internalPublicDescriptor: 'desc',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.zero,
);

void main() {
  late _MockBip85Repository bip85Repository;
  late _MockWalletRepository walletRepository;
  late _MockSeedRepository seedRepository;
  late _MockGetDefaultSeedUsecase getDefaultSeedUsecase;
  late _MockSettingsRepository settingsRepository;

  setUp(() {
    bip85Repository = _MockBip85Repository();
    walletRepository = _MockWalletRepository();
    seedRepository = _MockSeedRepository();
    getDefaultSeedUsecase = _MockGetDefaultSeedUsecase();
    settingsRepository = _MockSettingsRepository();
    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
  });

  group('DeriveNextBip85MnemonicFromDefaultWalletUsecase', () {
    late DeriveNextBip85MnemonicFromDefaultWalletUsecase usecase;

    setUp(() {
      usecase = DeriveNextBip85MnemonicFromDefaultWalletUsecase(
        bip85Repository: bip85Repository,
        walletRepository: walletRepository,
        seedRepository: seedRepository,
        settingsRepository: settingsRepository,
      );
    });

    test(
      'a failed wallet read is NOT reported as "no default wallet"',
      () async {
        // An onboarded install always has a default bitcoin and a default
        // liquid wallet, so an empty list means "not set up" while a failure
        // means "could not read". Collapsing the two would tell a user with a
        // perfectly good wallet that they have none.
        when(
          () => walletRepository.getWallets(
            onlyDefaults: any(named: 'onlyDefaults'),
            onlyBitcoin: any(named: 'onlyBitcoin'),
            environment: any(named: 'environment'),
          ),
        ).thenAnswer(
          (_) async => const Err<List<Wallet>, WalletFailure>(
            WalletStorageFailure(
              'SqliteException(11): database disk image is malformed',
            ),
          ),
        );

        final result = await usecase.execute();

        final failure = (result as Err).failure as Bip85Failure;
        expect(failure, isA<Bip85UnexpectedFailure>());
        expect(failure, isNot(isA<Bip85NoDefaultWalletFailure>()));
        // The wallet layer's reason stays in the log.
        expect(failure.logMessage, isNot(contains('disk image is malformed')));
      },
    );

    test(
      'returns Bip85NoDefaultWalletFailure when no default wallet exists',
      () async {
        when(
          () => walletRepository.getWallets(
            onlyDefaults: any(named: 'onlyDefaults'),
            onlyBitcoin: any(named: 'onlyBitcoin'),
            environment: any(named: 'environment'),
          ),
        ).thenAnswer((_) async => Ok([]));

        final result = await usecase.execute();

        expect(result, isA<Err<dynamic, Bip85Failure>>());
        final failure = (result as Err).failure;
        expect(failure, isA<Bip85NoDefaultWalletFailure>());
        expect(failure.logMessage, isNull);
      },
    );

    test(
      'returns Bip85UnexpectedFailure when wallet repository throws',
      () async {
        when(
          () => walletRepository.getWallets(
            onlyDefaults: any(named: 'onlyDefaults'),
            onlyBitcoin: any(named: 'onlyBitcoin'),
            environment: any(named: 'environment'),
          ),
        ).thenThrow(Exception('internal db error with secret path /data/user'));

        final result = await usecase.execute();

        expect(result, isA<Err<dynamic, Bip85Failure>>());
        final failure = (result as Err).failure;
        expect(failure, isA<Bip85UnexpectedFailure>());
        expect(failure.logMessage, isNotNull);
      },
    );
  });

  group('DeriveNextBip85HexFromDefaultWalletUsecase', () {
    late DeriveNextBip85HexFromDefaultWalletUsecase usecase;

    setUp(() {
      usecase = DeriveNextBip85HexFromDefaultWalletUsecase(
        bip85Repository: bip85Repository,
        walletRepository: walletRepository,
        seedRepository: seedRepository,
        settingsRepository: settingsRepository,
      );
    });

    test(
      'a failed wallet read is NOT reported as "no default wallet"',
      () async {
        // An onboarded install always has a default bitcoin and a default
        // liquid wallet, so an empty list means "not set up" while a failure
        // means "could not read". Collapsing the two would tell a user with a
        // perfectly good wallet that they have none.
        when(
          () => walletRepository.getWallets(
            onlyDefaults: any(named: 'onlyDefaults'),
            onlyBitcoin: any(named: 'onlyBitcoin'),
            environment: any(named: 'environment'),
          ),
        ).thenAnswer(
          (_) async => const Err<List<Wallet>, WalletFailure>(
            WalletStorageFailure(
              'SqliteException(11): database disk image is malformed',
            ),
          ),
        );

        final result = await usecase.execute(length: 30);

        final failure = (result as Err).failure as Bip85Failure;
        expect(failure, isA<Bip85UnexpectedFailure>());
        expect(failure, isNot(isA<Bip85NoDefaultWalletFailure>()));
        // The wallet layer's reason stays in the log.
        expect(failure.logMessage, isNot(contains('disk image is malformed')));
      },
    );

    test(
      'returns Bip85NoDefaultWalletFailure when no default wallet exists',
      () async {
        when(
          () => walletRepository.getWallets(
            onlyDefaults: any(named: 'onlyDefaults'),
            onlyBitcoin: any(named: 'onlyBitcoin'),
            environment: any(named: 'environment'),
          ),
        ).thenAnswer((_) async => Ok([]));

        final result = await usecase.execute(length: 30);

        expect(result, isA<Err<dynamic, Bip85Failure>>());
        expect((result as Err).failure, isA<Bip85NoDefaultWalletFailure>());
      },
    );

    test(
      'returns Bip85UnexpectedFailure when seed repository throws',
      () async {
        when(
          () => walletRepository.getWallets(
            onlyDefaults: any(named: 'onlyDefaults'),
            onlyBitcoin: any(named: 'onlyBitcoin'),
            environment: any(named: 'environment'),
          ),
        ).thenAnswer((_) async => Ok([_fakeWallet]));

        when(
          () => seedRepository.get(any()),
        ).thenThrow(Exception('seed not found'));

        final result = await usecase.execute(length: 30);

        expect(result, isA<Err<dynamic, Bip85Failure>>());
        final failure = (result as Err).failure;
        expect(failure, isA<Bip85UnexpectedFailure>());
        expect(failure.logMessage, isNotNull);
      },
    );

    test(
      'forwards Bip85StorageFailure from repository fetchNextIndex',
      () async {
        when(
          () => walletRepository.getWallets(
            onlyDefaults: any(named: 'onlyDefaults'),
            onlyBitcoin: any(named: 'onlyBitcoin'),
            environment: any(named: 'environment'),
          ),
        ).thenAnswer((_) async => Ok([_fakeWallet]));

        when(
          () => seedRepository.get(any()),
        ).thenThrow(Exception('seed not found'));

        final result = await usecase.execute(length: 30);

        // The seed lookup throws (a shared core repo), so the use-case maps it
        // to the sanitized catch-all — never a raw exception, never the typed
        // no-default-wallet failure.
        expect(result, isA<Err<dynamic, Bip85Failure>>());
        final failure = (result as Err).failure;
        expect(failure, isA<Bip85UnexpectedFailure>());
        expect(failure, isNot(isA<Bip85NoDefaultWalletFailure>()));
      },
    );
  });

  group('FetchAllBip85DerivationsWithEntropyUsecase', () {
    late FetchAllBip85DerivationsWithEntropyUsecase usecase;

    setUp(() {
      usecase = FetchAllBip85DerivationsWithEntropyUsecase(
        bip85Repository: bip85Repository,
        getDefaultSeedUsecase: getDefaultSeedUsecase,
      );
    });

    test(
      'returns Bip85UnexpectedFailure when the default seed cannot be read',
      () async {
        // The seed use case returns a failure now rather than throwing.
        when(() => getDefaultSeedUsecase.execute()).thenAnswer(
          (_) async => const Err<Seed, SeedFailure>(
            SeedFetchFailure('internal db error with secret path /data/user'),
          ),
        );

        final result = await usecase.execute();

        expect(result, isA<Err<dynamic, Bip85Failure>>());
        final failure = (result as Err).failure;
        expect(failure, isA<Bip85UnexpectedFailure>());
        // logMessage is for the log only, and must not carry the seed layer's
        // reason across the boundary.
        expect(failure.logMessage, isNotNull);
        expect(failure.logMessage, isNot(contains('/data/user')));
      },
    );
  });
}
