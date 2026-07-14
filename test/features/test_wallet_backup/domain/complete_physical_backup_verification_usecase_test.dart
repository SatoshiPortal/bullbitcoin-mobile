import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/complete_physical_backup_verification_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  const fingerprint = 'f00dbabe';
  late _MockWalletRepository walletRepository;
  late _MockSettingsRepository settingsRepository;
  late CompletePhysicalBackupVerificationUsecase usecase;

  Wallet wallet({
    required String origin,
    String masterFingerprint = fingerprint,
    bool encrypted = false,
    DateTime? encryptedAt,
  }) => Wallet(
    origin: origin,
    network: Network.bitcoinMainnet,
    masterFingerprint: masterFingerprint,
    xpubFingerprint: 'xpub-$origin',
    scriptType: ScriptType.bip84,
    xpub: 'xpub',
    externalPublicDescriptor: 'wpkh(xpub/0/*)',
    internalPublicDescriptor: 'wpkh(xpub/1/*)',
    signer: SignerEntity.local,
    signerDevice: null,
    balanceSat: BigInt.zero,
    isEncryptedVaultTested: encrypted,
    latestEncryptedBackup: encryptedAt,
  );

  setUp(() {
    walletRepository = _MockWalletRepository();
    settingsRepository = _MockSettingsRepository();
    usecase = CompletePhysicalBackupVerificationUsecase(
      walletRepository,
      settingsRepository,
    );
    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CRC',
      ),
    );
  });

  test('timestamps every wallet belonging to the verified seed', () async {
    final encryptedAt = DateTime.utc(2026, 1, 1);
    final defaultWallet = wallet(
      origin: 'default',
      encrypted: true,
      encryptedAt: encryptedAt,
    );
    final importedWallet = wallet(origin: 'imported');
    final unrelatedWallet = wallet(
      origin: 'unrelated',
      masterFingerprint: 'decafbad',
    );
    when(
      () => walletRepository.getWallets(environment: Environment.mainnet),
    ).thenAnswer((_) async => [defaultWallet, importedWallet, unrelatedWallet]);
    when(
      () => walletRepository.updateBackupInfo(
        isEncryptedVaultTested: any(named: 'isEncryptedVaultTested'),
        isPhysicalBackupTested: true,
        latestEncryptedBackup: any(named: 'latestEncryptedBackup'),
        latestPhysicalBackup: any(named: 'latestPhysicalBackup'),
        walletId: any(named: 'walletId'),
      ),
    ).thenAnswer((_) async {});
    final before = DateTime.now();

    final result = await usecase.execute(masterFingerprint: fingerprint);

    final after = DateTime.now();
    expect(result, isA<Ok>());
    final defaultTimestamp =
        verify(
              () => walletRepository.updateBackupInfo(
                isEncryptedVaultTested: true,
                isPhysicalBackupTested: true,
                latestEncryptedBackup: encryptedAt,
                latestPhysicalBackup: captureAny(named: 'latestPhysicalBackup'),
                walletId: 'default',
              ),
            ).captured.single
            as DateTime;
    final importedTimestamp =
        verify(
              () => walletRepository.updateBackupInfo(
                isEncryptedVaultTested: false,
                isPhysicalBackupTested: true,
                latestEncryptedBackup: null,
                latestPhysicalBackup: captureAny(named: 'latestPhysicalBackup'),
                walletId: 'imported',
              ),
            ).captured.single
            as DateTime;

    expect(defaultTimestamp, importedTimestamp);
    expect(defaultTimestamp.isBefore(before), isFalse);
    expect(defaultTimestamp.isAfter(after), isFalse);
    verifyNever(
      () => walletRepository.updateBackupInfo(
        isEncryptedVaultTested: any(named: 'isEncryptedVaultTested'),
        isPhysicalBackupTested: any(named: 'isPhysicalBackupTested'),
        latestEncryptedBackup: any(named: 'latestEncryptedBackup'),
        latestPhysicalBackup: any(named: 'latestPhysicalBackup'),
        walletId: 'unrelated',
      ),
    );
  });

  test('fails instead of recording completion for the wrong seed', () async {
    when(
      () => walletRepository.getWallets(environment: Environment.mainnet),
    ).thenAnswer(
      (_) async => [wallet(origin: 'unrelated', masterFingerprint: 'decafbad')],
    );

    final result = await usecase.execute(masterFingerprint: fingerprint);

    expect(result, isA<Err>());
    verifyNever(
      () => walletRepository.updateBackupInfo(
        isEncryptedVaultTested: any(named: 'isEncryptedVaultTested'),
        isPhysicalBackupTested: any(named: 'isPhysicalBackupTested'),
        latestEncryptedBackup: any(named: 'latestEncryptedBackup'),
        latestPhysicalBackup: any(named: 'latestPhysicalBackup'),
        walletId: any(named: 'walletId'),
      ),
    );
  });
}
