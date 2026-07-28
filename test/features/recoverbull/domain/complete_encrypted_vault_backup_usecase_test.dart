import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bb_mobile/features/recoverbull/domain/complete_encrypted_vault_backup_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

void main() {
  late _MockWalletRepository walletRepository;
  late CompleteEncryptedVaultBackupUsecase usecase;

  setUpAll(() => registerFallbackValue(DateTime.utc(2000)));

  setUp(() {
    walletRepository = _MockWalletRepository();
    usecase = CompleteEncryptedVaultBackupUsecase(walletRepository);
  });

  test('timestamps only the wallet used to create the vault', () async {
    when(
      () => walletRepository.updateEncryptedBackupTime(
        time: any(named: 'time'),
        walletId: 'bitcoin',
      ),
    ).thenAnswer((_) async {});
    final before = DateTime.now();

    final result = await usecase.execute(walletId: 'bitcoin');

    final after = DateTime.now();
    expect(result, isA<Ok>());
    final timestamp =
        verify(
              () => walletRepository.updateEncryptedBackupTime(
                time: captureAny(named: 'time'),
                walletId: 'bitcoin',
              ),
            ).captured.single
            as DateTime;
    expect(timestamp.isBefore(before), isFalse);
    expect(timestamp.isAfter(after), isFalse);
  });

  test('maps a wallet persistence error to a Recoverbull failure', () async {
    when(
      () => walletRepository.updateEncryptedBackupTime(
        time: any(named: 'time'),
        walletId: 'missing',
      ),
    ).thenThrow(const WalletError.notFound('missing'));

    final result = await usecase.execute(walletId: 'missing');

    expect(result, isA<Err>());
  });
}
