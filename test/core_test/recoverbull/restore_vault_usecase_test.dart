import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/restore_vault_usecase.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _CreateDefaults extends Mock implements CreateDefaultWalletsUsecase {}

class _Wallets extends Mock implements WalletRepository {}

class _Wallet extends Mock implements Wallet {}

void main() {
  setUpAll(() => registerFallbackValue(DateTime.utc(2026)));
  for (final createdIds in [
    <String>{},
    {'new'},
  ]) {
    test('forwards only created IDs to metadata recovery: $createdIds', () async {
      final create = _CreateDefaults();
      final wallets = _Wallets();
      final existing = _Wallet();
      final newlyCreated = _Wallet();
      when(() => existing.id).thenReturn('existing');
      when(() => newlyCreated.id).thenReturn('new');
      when(
        () => create.execute(mnemonicWords: any(named: 'mnemonicWords')),
      ).thenAnswer(
        (_) async => (
          wallets: [existing, if (createdIds.isNotEmpty) newlyCreated],
          createdWalletIds: createdIds,
        ),
      );
      when(
        () => wallets.updateEncryptedBackupTime(
          time: any(named: 'time'),
          walletId: any(named: 'walletId'),
        ),
      ).thenAnswer((_) async {});
      final result =
          await RestoreVaultUsecase(
            walletRepository: wallets,
            createDefaultWalletsUsecase: create,
          ).execute(
            decryptedVault: DecryptedVault(
              mnemonic:
                  'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about'
                      .split(' '),
            ),
          );
      expect(result, isA<Ok<List<String>, RecoverBullCoreFailure>>());
      expect(
        (result as Ok<List<String>, RecoverBullCoreFailure>).value.toSet(),
        createdIds,
      );
      verify(
        () => wallets.updateEncryptedBackupTime(
          time: any(named: 'time'),
          walletId: 'existing',
        ),
      ).called(1);
    });
  }
}
