import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/restore_vault_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_birthday_checkpoint.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockCreateDefaultWalletsUsecase extends Mock
    implements CreateDefaultWalletsUsecase {}

class _MockWallet extends Mock implements Wallet {}

void main() {
  late _MockWalletRepository walletRepository;
  late _MockCreateDefaultWalletsUsecase createDefaultWallets;
  late RestoreVaultUsecase usecase;

  final decryptedVault = DecryptedVault(
    mnemonic: List.filled(12, 'abandon')..[11] = 'about',
  );

  final fakeCheckpoint = WalletBirthdayCheckpoint(
    requestedBirthday: DateTime.utc(2020),
    blockTimestamp: DateTime.utc(2020),
    blockHeight: 600000,
    blockHash: 'a' * 64,
  );

  setUp(() {
    walletRepository = _MockWalletRepository();
    createDefaultWallets = _MockCreateDefaultWalletsUsecase();
    usecase = RestoreVaultUsecase(
      walletRepository: walletRepository,
      createDefaultWalletsUsecase: createDefaultWallets,
    );

    when(
      () => walletRepository.updateEncryptedBackupTime(
        time: any(named: 'time'),
        walletId: any(named: 'walletId'),
      ),
    ).thenAnswer((_) async {});
  });

  test(
    'forwards a resolved birthday checkpoint through to '
    'CreateDefaultWalletsUsecase unchanged — this use-case never resolves '
    'or second-guesses one itself, only the bloc (after its own '
    'birthday-picker UI) does',
    () async {
      final wallet = _MockWallet();
      when(() => wallet.id).thenReturn('wallet-1');
      when(
        () => createDefaultWallets.execute(
          mnemonicWords: any(named: 'mnemonicWords'),
          bitcoinBirthdayCheckpoint: any(named: 'bitcoinBirthdayCheckpoint'),
        ),
      ).thenAnswer((_) async => [wallet]);

      final result = await usecase.execute(
        decryptedVault: decryptedVault,
        bitcoinBirthdayCheckpoint: fakeCheckpoint,
      );

      expect(result, isA<Ok<Null, dynamic>>());
      verify(
        () => createDefaultWallets.execute(
          mnemonicWords: decryptedVault.mnemonic,
          bitcoinBirthdayCheckpoint: fakeCheckpoint,
        ),
      ).called(1);
    },
  );

  test(
    'a null checkpoint (no CBF preference, or Electrum) is forwarded as '
    'null — CreateDefaultWalletsUsecase decides whether that is fine',
    () async {
      final wallet = _MockWallet();
      when(() => wallet.id).thenReturn('wallet-1');
      when(
        () => createDefaultWallets.execute(
          mnemonicWords: any(named: 'mnemonicWords'),
          bitcoinBirthdayCheckpoint: any(named: 'bitcoinBirthdayCheckpoint'),
        ),
      ).thenAnswer((_) async => [wallet]);

      final result = await usecase.execute(decryptedVault: decryptedVault);

      expect(result, isA<Ok<Null, dynamic>>());
      verify(
        () => createDefaultWallets.execute(
          mnemonicWords: decryptedVault.mnemonic,
          bitcoinBirthdayCheckpoint: null,
        ),
      ).called(1);
    },
  );

  test(
    'a CreateDefaultWalletsUsecase failure (e.g. checkpoint required but '
    'missing) is mapped to an Err — no backup-time update is attempted',
    () async {
      when(
        () => createDefaultWallets.execute(
          mnemonicWords: any(named: 'mnemonicWords'),
          bitcoinBirthdayCheckpoint: any(named: 'bitcoinBirthdayCheckpoint'),
        ),
      ).thenThrow(CreateDefaultWalletsException('boom'));

      final result = await usecase.execute(
        decryptedVault: decryptedVault,
        bitcoinBirthdayCheckpoint: fakeCheckpoint,
      );

      expect(result, isA<Err<Null, dynamic>>());
      verifyNever(
        () => walletRepository.updateEncryptedBackupTime(
          time: any(named: 'time'),
          walletId: any(named: 'walletId'),
        ),
      );
    },
  );
}
