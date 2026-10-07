import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/update_latest_encrypted_backup_usecase.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockSettings extends Mock implements SettingsEntity {}

class _MockWallet extends Mock implements Wallet {}

const _vault = DecryptedVault(
  mnemonic: [
    'zoo',
    'zoo',
    'zoo',
    'zoo',
    'zoo',
    'zoo',
    'zoo',
    'zoo',
    'zoo',
    'zoo',
    'zoo',
    'wrong',
  ],
);

void main() {
  test(
    'testing another vault preserves an existing wallet verification',
    () async {
      final walletRepository = _MockWalletRepository();
      final settingsRepository = _MockSettingsRepository();
      final settings = _MockSettings();
      final wallet = _MockWallet();
      final verifiedAt = DateTime.utc(2026, 9, 1);
      DateTime? storedVerification = verifiedAt;

      when(() => settings.environment).thenReturn(Environment.mainnet);
      when(settingsRepository.fetch).thenAnswer((_) async => settings);
      when(() => wallet.id).thenReturn('previously-verified-wallet');
      // The existing wallet has a different root from the public zoo fixture.
      when(() => wallet.masterFingerprint).thenReturn('73c5da0a');
      when(
        () => walletRepository.getWallets(
          onlyDefaults: true,
          environment: Environment.mainnet,
        ),
      ).thenAnswer((_) async => Ok([wallet]));
      when(
        () => walletRepository.updateEncryptedBackupTime(
          time: any(named: 'time'),
          walletId: any(named: 'walletId'),
        ),
      ).thenAnswer((invocation) async {
        storedVerification = invocation.namedArguments[#time] as DateTime?;
      });

      final usecase = UpdateLatestEncryptedVaultTestUsecase(
        walletRepository: walletRepository,
        settingsRepository: settingsRepository,
      );

      await usecase.execute(decryptedVault: _vault);

      // Decrypting another backup says nothing about the prior verification.
      // This invariant does not prescribe whether foreign vaults are accepted.
      expect(storedVerification, verifiedAt);
      verifyNever(
        () => walletRepository.updateEncryptedBackupTime(
          time: any(named: 'time'),
          walletId: 'previously-verified-wallet',
        ),
      );
    },
  );

  test('testing a matching vault records verification', () async {
    final walletRepository = _MockWalletRepository();
    final settingsRepository = _MockSettingsRepository();
    final settings = _MockSettings();
    final wallet = _MockWallet();
    DateTime? storedVerification;
    when(() => settings.environment).thenReturn(Environment.mainnet);
    when(settingsRepository.fetch).thenAnswer((_) async => settings);
    when(() => wallet.id).thenReturn('matching-wallet');
    when(() => wallet.masterFingerprint).thenReturn('3f635a63');
    when(
      () => walletRepository.getWallets(
        onlyDefaults: true,
        environment: Environment.mainnet,
      ),
    ).thenAnswer((_) async => Ok([wallet]));
    when(
      () => walletRepository.updateEncryptedBackupTime(
        time: any(named: 'time'),
        walletId: 'matching-wallet',
      ),
    ).thenAnswer((invocation) async {
      storedVerification = invocation.namedArguments[#time] as DateTime?;
    });
    final usecase = UpdateLatestEncryptedVaultTestUsecase(
      walletRepository: walletRepository,
      settingsRepository: settingsRepository,
    );
    final started = DateTime.now();
    final result = await usecase.execute(decryptedVault: _vault);
    expect(result, isA<Ok>());
    expect(storedVerification, isNotNull);
    expect(storedVerification!.isBefore(started), isFalse);
    verify(
      () => walletRepository.updateEncryptedBackupTime(
        time: any(named: 'time'),
        walletId: 'matching-wallet',
      ),
    ).called(1);
  });
}
