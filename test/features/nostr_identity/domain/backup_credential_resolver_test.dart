import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'dart:io';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/nostr_identity/domain/backup_credential_resolver.dart';
import 'package:bb_mobile/features/nostr_identity/domain/nostr_identity_failure.dart';
import 'package:primitives/primitives.dart' show Ok, Err;
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../fixtures/backup_secret_fixture.dart';
import '../fixtures/backup_credential_vectors.dart';

class _Settings extends Mock implements GetSettingsUsecase {}

class _Wallets extends Mock implements WalletRepository {}

class _Wallet extends Mock implements Wallet {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'the resolver selects the current environment default secret on each operation',
    () async {
      final seed = await backupSecretFixture();
      final wallet = _Wallet();
      when(() => wallet.singleLocalSeedFingerprint).thenReturn(seed.id.hex);
      final wallets = _Wallets();
      final settings = _Settings();
      var environment = Environment.testnet;
      when(settings.execute).thenAnswer(
        (_) async => SettingsEntity(
          environment: environment,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      );
      for (final env in Environment.values) {
        when(
          () => wallets.getWallets(
            environment: env,
            onlyDefaults: true,
            onlyBitcoin: true,
          ),
        ).thenAnswer((_) async => Ok([wallet]));
      }
      final resolver = BackupCredentialResolver(
        getSettings: settings,
        wallets: wallets,
        secrets: Secrets(
          scratchDirectory: () async => Directory.systemTemp.path,
        ),
      );
      for (final env in [Environment.testnet, Environment.mainnet]) {
        environment = env;
        final result = await resolver.resolve();
        expect(
          (result as Ok<BackupCredential, NostrIdentityFailure>)
              .value
              .serverPublicKey,
          backupCredentialVectorServerPublicKey,
        );
        verify(
          () => wallets.getWallets(
            environment: env,
            onlyDefaults: true,
            onlyBitcoin: true,
          ),
        ).called(1);
      }
    },
  );

  test('words-only recovery needs neither local storage nor settings', () {
    FakeSecureStoragePlatform(locked: true).install();
    final settings = _Settings(), wallets = _Wallets();
    final resolver = BackupCredentialResolver(
      getSettings: settings,
      wallets: wallets,
      secrets: Secrets(scratchDirectory: () async => Directory.systemTemp.path),
    );
    final result = resolver.fromWords(backupCredentialVectorWords);
    expect(
      (result as Ok<BackupCredential, NostrIdentityFailure>)
          .value
          .artifactPublicKey,
      backupCredentialVectorNostrPublicKey,
    );
    verifyZeroInteractions(settings);
    verifyZeroInteractions(wallets);
  });

  test(
    'credential failures contain neither underlying exceptions nor input',
    () async {
      FakeSecureStoragePlatform(locked: true).install();
      final settings = _Settings(), wallets = _Wallets();
      when(settings.execute).thenThrow(Exception('private fixture details'));
      final resolver = BackupCredentialResolver(
        getSettings: settings,
        wallets: wallets,
        secrets: Secrets(
          scratchDirectory: () async => Directory.systemTemp.path,
        ),
      );
      final unavailable = await resolver.resolve();
      expect(
        (unavailable as Err<BackupCredential, NostrIdentityFailure>).failure,
        isA<BackupCredentialUnavailable>(),
      );
      expect(unavailable.failure.logMessage, isNull);
      when(settings.execute).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      );
      when(
        () => wallets.getWallets(
          environment: Environment.mainnet,
          onlyDefaults: true,
          onlyBitcoin: true,
        ),
      ).thenAnswer((_) async => const Ok([]));
      expect(
        await resolver.resolve(),
        isA<Err<BackupCredential, NostrIdentityFailure>>(),
      );
      final invalid = resolver.fromWords('private fixture input');
      expect(
        (invalid as Err<BackupCredential, NostrIdentityFailure>).failure,
        isA<InvalidDataRecoveryWords>(),
      );
      expect(invalid.failure.logMessage, isNull);
    },
  );
}
