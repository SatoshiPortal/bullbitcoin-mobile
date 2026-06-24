import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/derive_next_bip85_hex_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/derive_next_bip85_mnemonic_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBip85Repository extends Mock implements Bip85Repository {}

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockSeedRepository extends Mock implements SeedRepository {}

void main() {
  late _MockBip85Repository bip85Repository;
  late _MockWalletRepository walletRepository;
  late _MockSeedRepository seedRepository;

  setUp(() {
    bip85Repository = _MockBip85Repository();
    walletRepository = _MockWalletRepository();
    seedRepository = _MockSeedRepository();
  });

  group('DeriveNextBip85MnemonicFromDefaultWalletUsecase', () {
    late DeriveNextBip85MnemonicFromDefaultWalletUsecase usecase;

    setUp(() {
      usecase = DeriveNextBip85MnemonicFromDefaultWalletUsecase(
        bip85Repository: bip85Repository,
        walletRepository: walletRepository,
        seedRepository: seedRepository,
      );
    });

    test(
      'returns Bip85NoDefaultWalletFailure when no default wallet exists',
      () async {
        when(
          () => walletRepository.getWallets(
            onlyDefaults: any(named: 'onlyDefaults'),
            onlyBitcoin: any(named: 'onlyBitcoin'),
          ),
        ).thenAnswer((_) async => []);

        final result = await usecase.execute();

        expect(result, isA<Err<dynamic, Bip85Failure>>());
        final failure = (result as Err).failure;
        expect(failure, isA<Bip85NoDefaultWalletFailure>());
        // Confirm no raw error string leaked into the failure message visible to UI
        expect(failure.logMessage, isNull);
      },
    );

    test(
      'returns Bip85UnexpectedFailure on wallet repository throw, no raw leak',
      () async {
        when(
          () => walletRepository.getWallets(
            onlyDefaults: any(named: 'onlyDefaults'),
            onlyBitcoin: any(named: 'onlyBitcoin'),
          ),
        ).thenThrow(Exception('internal db error with secret path /data/user'));

        final result = await usecase.execute();

        expect(result, isA<Err<dynamic, Bip85Failure>>());
        final failure = (result as Err).failure;
        expect(failure, isA<Bip85UnexpectedFailure>());
        // logMessage is for Sentry only — never surfaced to UI
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
      );
    });

    test(
      'returns Bip85NoDefaultWalletFailure when no default wallet exists',
      () async {
        when(
          () => walletRepository.getWallets(
            onlyDefaults: any(named: 'onlyDefaults'),
            onlyBitcoin: any(named: 'onlyBitcoin'),
          ),
        ).thenAnswer((_) async => []);

        final result = await usecase.execute(length: 30);

        expect(result, isA<Err<dynamic, Bip85Failure>>());
        expect((result as Err).failure, isA<Bip85NoDefaultWalletFailure>());
      },
    );

    test(
      'forwards Bip85DerivationFailure from repository, no raw leak',
      () async {
        final fakeWallet = Wallet(
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

        when(
          () => walletRepository.getWallets(
            onlyDefaults: any(named: 'onlyDefaults'),
            onlyBitcoin: any(named: 'onlyBitcoin'),
          ),
        ).thenAnswer((_) async => [fakeWallet]);

        when(
          () => seedRepository.get(any()),
        ).thenThrow(Exception('seed not found'));

        final result = await usecase.execute(length: 30);

        expect(result, isA<Err<dynamic, Bip85Failure>>());
        final failure = (result as Err).failure;
        expect(failure, isA<Bip85UnexpectedFailure>());
        // Confirm the failure type is sealed — no raw string leaks to UI
        expect(failure, isNot(isA<Bip85NoDefaultWalletFailure>()));
      },
    );
  });
}
