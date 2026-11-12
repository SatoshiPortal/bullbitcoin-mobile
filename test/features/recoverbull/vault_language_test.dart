import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/recoverbull/domain/usecases/create_encrypted_vault_usecase.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _Settings extends Mock implements SettingsRepository {}

class _Wallets extends Mock implements WalletRepository {}

class _Wallet extends Mock implements Wallet {}

void main() {
  test('vault creation seals a French mnemonic', () async {
    FakeSecureStoragePlatform().install();
    final secrets = Secrets(scratchDirectory: () async => '/tmp');
    final secret = switch (await secrets.import(
      words: bip39.Mnemonic(List.filled(16, 0), bip39.Language.french).words,
      language: bip39.Language.french,
    )) {
      Ok(:final value) => value,
      Err() => throw StateError('public vector import failed'),
    };
    final settings = _Settings();
    final wallets = _Wallets();
    final wallet = _Wallet();
    when(() => settings.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    when(() => wallet.masterFingerprint).thenReturn(secret.id.hex);
    when(() => wallet.isEncryptedVaultTested).thenReturn(false);
    when(() => wallet.isPhysicalBackupTested).thenReturn(false);
    when(() => wallet.latestEncryptedBackup).thenReturn(null);
    when(() => wallet.latestPhysicalBackup).thenReturn(null);
    when(
      () => wallets.getWallets(
        onlyBitcoin: true,
        onlyDefaults: true,
        environment: Environment.mainnet,
      ),
    ).thenAnswer((_) async => Ok([wallet]));
    final result = await CreateEncryptedVaultUsecase(
      secrets: secrets,
      walletRepository: wallets,
      settingsRepository: settings,
    ).execute();
    expect(result, isA<Ok>());
    verifyNever(
      () => wallets.updateEncryptedBackupTime(
        time: any(named: 'time'),
        walletId: any(named: 'walletId'),
      ),
    );
  });
}
