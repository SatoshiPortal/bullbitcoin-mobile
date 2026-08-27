import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/recoverbull/domain/complete_encrypted_vault_backup_usecase.dart';
import 'package:bb_mobile/features/recoverbull/domain/recoverbull_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

void main() {
  late _MockWalletRepository wallets;
  late CompleteEncryptedVaultBackupUsecase usecase;

  setUp(() {
    wallets = _MockWalletRepository();
    usecase = CompleteEncryptedVaultBackupUsecase(wallets);
  });

  test('marks the wallet only after the encrypted vault is durable', () async {
    when(
      () => wallets.updateEncryptedBackupTime(
        time: any(named: 'time'),
        walletId: 'wallet-a',
      ),
    ).thenAnswer((_) async {});

    final result = await usecase.execute(walletId: 'wallet-a');

    expect(result, const Ok<void, RecoverBullFailure>(null));
    verify(
      () => wallets.updateEncryptedBackupTime(
        time: any(named: 'time'),
        walletId: 'wallet-a',
      ),
    ).called(1);
  });

  test(
    'returns a typed failure when the completion marker cannot persist',
    () async {
      when(
        () => wallets.updateEncryptedBackupTime(
          time: any(named: 'time'),
          walletId: 'wallet-a',
        ),
      ).thenThrow(Exception('storage unavailable'));

      final result = await usecase.execute(walletId: 'wallet-a');

      expect(
        result,
        const Err<void, RecoverBullFailure>(VaultStatusPersistenceFailure()),
      );
    },
  );
}
