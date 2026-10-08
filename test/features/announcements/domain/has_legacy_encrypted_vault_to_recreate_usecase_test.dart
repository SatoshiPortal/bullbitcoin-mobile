import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/has_legacy_encrypted_vault_to_recreate_usecase.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockWallet extends Mock implements Wallet {}

Wallet _wallet({DateTime? latestEncryptedBackup}) {
  final wallet = _MockWallet();
  when(() => wallet.latestEncryptedBackup).thenReturn(latestEncryptedBackup);
  return wallet;
}

void main() {
  late _MockWalletRepository walletRepository;
  late RecoverBullStatus status;
  late HasLegacyEncryptedVaultToRecreateUsecase usecase;

  void givenDefaultMainnetWallets(List<Wallet> wallets) {
    when(
      () => walletRepository.getWallets(
        environment: Environment.mainnet,
        onlyDefaults: true,
      ),
    ).thenAnswer((_) async => Ok(wallets));
  }

  setUp(() {
    walletRepository = _MockWalletRepository();
    status = const RecoverBullStatus.initial();
    usecase = HasLegacyEncryptedVaultToRecreateUsecase(
      walletRepository: walletRepository,
      fetchRecoverBullStatus: () async => status,
    );
  });

  test('is true for a legacy vault RecoverBull does not know', () async {
    givenDefaultMainnetWallets([
      _wallet(),
      _wallet(latestEncryptedBackup: DateTime.utc(2026, 5, 1)),
    ]);

    expect(await usecase.execute(), isTrue);
  });

  test('is false without a legacy vault', () async {
    givenDefaultMainnetWallets([_wallet(), _wallet()]);

    expect(await usecase.execute(), isFalse);
  });

  test('is false once RecoverBull has an encrypted backup', () async {
    status = RecoverBullStatus(lastEncryptedBackupAt: DateTime.utc(2026, 10));
    givenDefaultMainnetWallets([
      _wallet(latestEncryptedBackup: DateTime.utc(2026, 5, 1)),
    ]);

    expect(await usecase.execute(), isFalse);
  });

  test('is false while the RecoverBull status is unknown', () async {
    status = const RecoverBullStatus.unavailable();
    givenDefaultMainnetWallets([
      _wallet(latestEncryptedBackup: DateTime.utc(2026, 5, 1)),
    ]);

    expect(await usecase.execute(), isFalse);
  });

  test('is false when the wallets cannot be read', () async {
    when(
      () => walletRepository.getWallets(
        environment: Environment.mainnet,
        onlyDefaults: true,
      ),
    ).thenAnswer((_) async => const Err(WalletStorageFailure('locked')));

    expect(await usecase.execute(), isFalse);
  });

  test('is false when the RecoverBull status throws', () async {
    usecase = HasLegacyEncryptedVaultToRecreateUsecase(
      walletRepository: walletRepository,
      fetchRecoverBullStatus: () async => throw StateError('closed'),
    );

    expect(await usecase.execute(), isFalse);
  });
}
