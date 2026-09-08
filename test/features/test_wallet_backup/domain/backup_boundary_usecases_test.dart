import 'dart:typed_data';

import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/onboarding/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/check_backup_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/complete_backup_verification_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/get_mnemonic_from_fingerprint_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/load_wallets_for_network_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockSeedRepository extends Mock implements SeedRepository {}

class _MockCompletePhysicalBackupVerificationUsecase extends Mock
    implements CompletePhysicalBackupVerificationUsecase {}

const _fingerprint = 'abcd1234';
const _mnemonicWords = ['legal', 'winner', 'thank', 'year'];

/// Deliberately leaky: a driver reason quoting a filesystem path, plus one
/// quoting seed material. Neither may travel further than logMessage.
const _rawReason = 'DriftRemoteException: locked at /data/user/0/app.sqlite';
const _secretReason = 'keychain failed for legal winner thank year';

const _settings = SettingsEntity(
  environment: Environment.mainnet,
  bitcoinUnit: BitcoinUnit.sats,
  currencyCode: 'USD',
);

Wallet _wallet({bool tested = false}) => Wallet(
  origin: 'w1',
  network: Network.bitcoinMainnet,
  xpubFingerprint: '00000000',
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.zero,
  confirmedBalanceSat: BigInt.zero,
  isPhysicalBackupTested: tested,
);

void main() {
  group('CheckBackupUsecase', () {
    late _MockWalletRepository wallets;
    late _MockSettingsRepository settings;
    late CheckBackupUsecase usecase;

    setUp(() {
      wallets = _MockWalletRepository();
      settings = _MockSettingsRepository();
      usecase = CheckBackupUsecase(
        walletRepository: wallets,
        settingsRepository: settings,
      );
      when(() => settings.fetch()).thenAnswer((_) async => _settings);
    });

    void stubWallets(List<Wallet> value) => when(
      () => wallets.getWallets(
        onlyDefaults: any(named: 'onlyDefaults'),
        environment: any(named: 'environment'),
      ),
    ).thenAnswer((_) async => value);

    test('no default wallets is Ok(false), not a failure: a fresh install '
        'legitimately has none', () async {
      stubWallets(const <Wallet>[]);

      final result = await usecase.execute();

      expect((result as Ok<bool, TestWalletBackupFailure>).value, isFalse);
    });

    test(
      'reports true as soon as one default wallet has been tested',
      () async {
        stubWallets([_wallet(), _wallet(tested: true)]);

        final result = await usecase.execute();

        expect((result as Ok<bool, TestWalletBackupFailure>).value, isTrue);
      },
    );

    test('a failed read is an Err, not a silent false, so the caller owns '
        'the fail-closed decision', () async {
      when(
        () => wallets.getWallets(
          onlyDefaults: any(named: 'onlyDefaults'),
          environment: any(named: 'environment'),
        ),
      ).thenThrow(Exception(_rawReason));

      final result = await usecase.execute();

      switch (result) {
        case Ok():
          fail('a failed read must not be reported as a backup answer');
        case Err(:final failure):
          expect(failure, isA<TestWalletBackupWalletsUnavailableFailure>());
          expect(failure.logMessage, contains('app.sqlite'));
      }
    });
  });

  group('LoadWalletsForNetworkUsecase', () {
    late _MockWalletRepository wallets;
    late _MockSettingsRepository settings;
    late LoadWalletsForNetworkUsecase usecase;

    setUp(() {
      wallets = _MockWalletRepository();
      settings = _MockSettingsRepository();
      usecase = LoadWalletsForNetworkUsecase(
        walletRepository: wallets,
        settingsRepository: settings,
      );
      when(() => settings.fetch()).thenAnswer((_) async => _settings);
    });

    test('reports an empty list as a distinct failure, not an empty Ok, so '
        'callers cannot trip over .first', () async {
      when(
        () => wallets.getWallets(
          onlyDefaults: any(named: 'onlyDefaults'),
          onlyBitcoin: any(named: 'onlyBitcoin'),
          environment: any(named: 'environment'),
        ),
      ).thenAnswer((_) async => const <Wallet>[]);

      final result = await usecase.execute();

      switch (result) {
        case Ok():
          fail('an empty wallet list must not be reported as success');
        case Err(:final failure):
          expect(failure, isA<TestWalletBackupNoWalletsFailure>());
      }
    });

    test(
      'maps a thrown read to a sanitized failure, raw reason logs-only',
      () async {
        when(
          () => wallets.getWallets(
            onlyDefaults: any(named: 'onlyDefaults'),
            onlyBitcoin: any(named: 'onlyBitcoin'),
            environment: any(named: 'environment'),
          ),
        ).thenThrow(Exception(_rawReason));

        final result = await usecase.execute();

        switch (result) {
          case Ok():
            fail('a thrown read must not be reported as wallets');
          case Err(:final failure):
            expect(failure, isA<TestWalletBackupWalletsUnavailableFailure>());
            expect(failure.logMessage, contains('app.sqlite'));
        }
      },
    );
  });

  group('GetMnemonicFromFingerprintUsecase', () {
    late _MockSeedRepository seeds;
    late GetMnemonicFromFingerprintUsecase usecase;

    setUp(() {
      seeds = _MockSeedRepository();
      usecase = GetMnemonicFromFingerprintUsecase(seedRepository: seeds);
    });

    test('returns the mnemonic and passphrase on success', () async {
      when(() => seeds.get(_fingerprint)).thenAnswer(
        (_) async => MnemonicSeed(
          mnemonicWords: _mnemonicWords,
          passphrase: 'pass',
          bytes: Uint8List.fromList([1, 2, 3]),
          masterFingerprint: _fingerprint,
        ),
      );

      final result = await usecase.execute(_fingerprint);

      final (
        words,
        passphrase,
      ) = (result as Ok<(List<String>, String?), TestWalletBackupFailure>)
          .value;
      expect(words, _mnemonicWords);
      expect(passphrase, 'pass');
    });

    test('maps a non-mnemonic seed to its own variant', () async {
      when(() => seeds.get(_fingerprint)).thenAnswer(
        (_) async => BytesSeed(
          bytes: Uint8List.fromList([1, 2, 3]),
          masterFingerprint: _fingerprint,
        ),
      );

      final result = await usecase.execute(_fingerprint);

      switch (result) {
        case Ok():
          fail('a non-mnemonic seed has no phrase to return');
        case Err(:final failure):
          expect(failure, isA<TestWalletBackupSeedNotMnemonicFailure>());
      }
    });

    test('drops a secret-shaped reason entirely rather than carrying it '
        'into a state-resident failure', () async {
      when(() => seeds.get(_fingerprint)).thenThrow(Exception(_secretReason));

      final result = await usecase.execute(_fingerprint);

      switch (result) {
        case Ok():
          fail('a thrown seed read must not be reported as a mnemonic');
        case Err(:final failure):
          expect(failure, isA<TestWalletBackupSeedUnavailableFailure>());
          // Logged at the boundary and dropped here: the seed path is the one
          // place where even logMessage is too far to carry a raw reason.
          expect(failure.logMessage, isNull);
          expect(failure.toString(), isNot(contains('legal winner')));
      }
    });
  });

  group('CompleteBackupVerificationUsecase', () {
    test('maps the onboarding exception, which carries e.toString(), into '
        'this feature\'s family', () async {
      final inner = _MockCompletePhysicalBackupVerificationUsecase();
      when(() => inner.execute()).thenThrow(Exception(_rawReason));

      final result = await CompleteBackupVerificationUsecase(inner).execute();

      switch (result) {
        case Ok():
          fail('a failed completion must not be reported as recorded');
        case Err(:final failure):
          expect(failure, isA<TestWalletBackupCompletionFailure>());
          expect(failure.logMessage, contains('app.sqlite'));
      }
    });

    test('returns Ok when the verification is recorded', () async {
      final inner = _MockCompletePhysicalBackupVerificationUsecase();
      when(() => inner.execute()).thenAnswer((_) async {});

      final result = await CompleteBackupVerificationUsecase(inner).execute();

      expect(result, isA<Ok<void, TestWalletBackupFailure>>());
    });
  });
}
