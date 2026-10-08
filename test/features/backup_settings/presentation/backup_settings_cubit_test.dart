import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/get_encrypted_backup_status_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';

class _GetWallets extends Mock implements GetWalletsUsecase {}

class _GetSettings extends Mock implements GetSettingsUsecase {}

class _Wallet extends Mock implements Wallet {}

class _Settings extends Mock implements SettingsEntity {}

class _GetEncryptedBackupStatus extends Mock
    implements GetEncryptedBackupStatusUsecase {}

_GetEncryptedBackupStatus _statusUsecase(
  Future<RecoverBullStatus> Function(Environment environment) answer,
) {
  final usecase = _GetEncryptedBackupStatus();
  when(
    () => usecase.execute(any()),
  ).thenAnswer((invocation) => answer(invocation.positionalArguments.single));
  return usecase;
}

void main() {
  setUpAll(() => registerFallbackValue(Environment.mainnet));

  test('maps encrypted backup presence from RecoverBullStatus', () async {
    final wallets = _GetWallets();
    final getSettings = _GetSettings();
    final wallet = _Wallet();
    final settings = _Settings();

    when(
      () => wallets.execute(onlyDefaults: true),
    ).thenAnswer((_) async => Ok([wallet]));
    when(() => wallet.isPhysicalBackupTested).thenReturn(false);
    when(() => wallet.network).thenReturn(Network.bitcoinMainnet);
    when(() => wallet.latestPhysicalBackup).thenReturn(null);
    when(() => getSettings.execute()).thenAnswer((_) async => settings);
    when(() => settings.environment).thenReturn(Environment.mainnet);

    final cubit = BackupSettingsCubit(
      getWalletsUsecase: wallets,
      getSettingsUsecase: getSettings,
      getEncryptedBackupStatusUsecase: _statusUsecase(
        (_) async => RecoverBullStatus(lastEncryptedBackupAt: DateTime(2026)),
      ),
    );
    addTearDown(cubit.close);

    await cubit.checkBackupStatus();

    expect(cubit.state.hasEncryptedBackup, isTrue);
  });

  test(
    'does not fall back to wallet metadata when package status is fresh',
    () async {
      final wallets = _GetWallets();
      final getSettings = _GetSettings();
      final wallet = _Wallet();
      final settings = _Settings();

      when(
        () => wallets.execute(onlyDefaults: true),
      ).thenAnswer((_) async => Ok([wallet]));
      when(() => wallet.isPhysicalBackupTested).thenReturn(false);
      when(() => wallet.network).thenReturn(Network.bitcoinMainnet);
      when(() => wallet.latestPhysicalBackup).thenReturn(null);
      when(() => wallet.latestEncryptedBackup).thenReturn(DateTime(2026));
      when(() => wallet.isEncryptedVaultTested).thenReturn(true);
      when(() => getSettings.execute()).thenAnswer((_) async => settings);
      when(() => settings.environment).thenReturn(Environment.mainnet);

      final cubit = BackupSettingsCubit(
        getWalletsUsecase: wallets,
        getSettingsUsecase: getSettings,
        getEncryptedBackupStatusUsecase: _statusUsecase(
          (_) async => const RecoverBullStatus.initial(),
        ),
      );
      addTearDown(cubit.close);

      await cubit.checkBackupStatus();

      expect(cubit.state.hasEncryptedBackup, isFalse);
      expect(cubit.state.isDefaultEncryptedBackupTested, isFalse);
      verifyNever(() => wallet.latestEncryptedBackup);
      verifyNever(() => wallet.isEncryptedVaultTested);
    },
  );

  test('does not use encrypted backup metadata from another network', () async {
    final wallets = _GetWallets();
    final getSettings = _GetSettings();
    final mainnetWallet = _Wallet();
    final testnetWallet = _Wallet();
    final settings = _Settings();

    when(
      () => wallets.execute(onlyDefaults: true),
    ).thenAnswer((_) async => Ok([mainnetWallet, testnetWallet]));
    when(() => mainnetWallet.isPhysicalBackupTested).thenReturn(false);
    when(() => mainnetWallet.network).thenReturn(Network.bitcoinMainnet);
    when(() => mainnetWallet.latestPhysicalBackup).thenReturn(null);
    when(() => testnetWallet.isPhysicalBackupTested).thenReturn(false);
    when(() => testnetWallet.network).thenReturn(Network.bitcoinTestnet);
    when(() => testnetWallet.latestPhysicalBackup).thenReturn(null);
    when(() => testnetWallet.latestEncryptedBackup).thenReturn(DateTime(2026));
    when(() => testnetWallet.isEncryptedVaultTested).thenReturn(true);
    when(() => getSettings.execute()).thenAnswer((_) async => settings);
    when(() => settings.environment).thenReturn(Environment.mainnet);

    final cubit = BackupSettingsCubit(
      getWalletsUsecase: wallets,
      getSettingsUsecase: getSettings,
      getEncryptedBackupStatusUsecase: _statusUsecase(
        (_) async => const RecoverBullStatus.initial(),
      ),
    );
    addTearDown(cubit.close);

    await cubit.checkBackupStatus();

    expect(cubit.state.hasEncryptedBackup, isFalse);
    expect(cubit.state.isDefaultEncryptedBackupTested, isFalse);
    verifyNever(() => testnetWallet.latestEncryptedBackup);
    verifyNever(() => testnetWallet.isEncryptedVaultTested);
  });

  test('reads the encrypted backup of the current testnet network', () async {
    final wallets = _GetWallets();
    final getSettings = _GetSettings();
    final wallet = _Wallet();
    final settings = _Settings();
    final asked = <Environment>[];

    when(
      () => wallets.execute(onlyDefaults: true),
    ).thenAnswer((_) async => Ok([wallet]));
    when(() => wallet.isPhysicalBackupTested).thenReturn(false);
    when(() => wallet.network).thenReturn(Network.bitcoinTestnet);
    when(() => wallet.latestPhysicalBackup).thenReturn(null);
    when(() => getSettings.execute()).thenAnswer((_) async => settings);
    when(() => settings.environment).thenReturn(Environment.testnet);

    final cubit = BackupSettingsCubit(
      getWalletsUsecase: wallets,
      getSettingsUsecase: getSettings,
      getEncryptedBackupStatusUsecase: _statusUsecase((environment) async {
        asked.add(environment);
        return environment == Environment.testnet
            ? RecoverBullStatus(lastEncryptedBackupAt: DateTime(2026))
            : const RecoverBullStatus.initial();
      }),
    );
    addTearDown(cubit.close);

    await cubit.checkBackupStatus();

    expect(asked, [Environment.testnet]);
    expect(cubit.state.hasEncryptedBackup, isTrue);
  });

  test(
    'a newly-created backup remains unverified until it is tested',
    () async {
      final wallets = _GetWallets();
      final getSettings = _GetSettings();
      final wallet = _Wallet();
      final settings = _Settings();

      when(
        () => wallets.execute(onlyDefaults: true),
      ).thenAnswer((_) async => Ok([wallet]));
      when(() => wallet.isPhysicalBackupTested).thenReturn(false);
      when(() => wallet.network).thenReturn(Network.bitcoinMainnet);
      when(() => wallet.latestPhysicalBackup).thenReturn(null);
      when(() => getSettings.execute()).thenAnswer((_) async => settings);
      when(() => settings.environment).thenReturn(Environment.mainnet);

      final cubit = BackupSettingsCubit(
        getWalletsUsecase: wallets,
        getSettingsUsecase: getSettings,
        getEncryptedBackupStatusUsecase: _statusUsecase(
          (_) async => RecoverBullStatus(lastEncryptedBackupAt: DateTime(2026)),
        ),
      );
      addTearDown(cubit.close);

      await cubit.checkBackupStatus();

      expect(cubit.state.hasEncryptedBackup, isTrue);
      expect(cubit.state.isDefaultEncryptedBackupTested, isFalse);
    },
  );
}
