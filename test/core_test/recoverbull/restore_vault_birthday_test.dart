import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/restore_vault_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Wallets extends Mock implements WalletRepository {}

class _Defaults extends Fake implements CreateDefaultWalletsUsecase {
  int calls = 0;
  int wordCount = 0;
  WalletBirthday? receivedBirthday;

  @override
  Future<List<Wallet>> execute({
    List<String>? mnemonicWords,
    String? passphrase,
    WalletBirthday? birthday,
  }) async {
    calls++;
    wordCount = mnemonicWords?.length ?? 0;
    receivedBirthday = birthday;
    return [];
  }
}

void main() {
  for (final birthday in <WalletBirthday?>[
    null,
    WalletBirthday(DateTime.parse('2020-03-02T01:30:00+02:00')),
  ]) {
    test(
      'vault restore forwards known birthday and preserves unknown',
      () async {
        final defaults = _Defaults();
        // Ephemeral words exercise the parser; no wallet or secret is persisted.
        final words = bip39.Mnemonic.generate(bip39.Language.english).words;
        final result =
            await RestoreVaultUsecase(
              walletRepository: _Wallets(),
              createDefaultWalletsUsecase: defaults,
            ).execute(
              decryptedVault: DecryptedVault(
                mnemonic: words,
                latestEncryptedBackup: DateTime.utc(2025),
              ),
              birthday: birthday,
            );
        expect(result, isA<Ok>());
        expect(defaults.calls, 1);
        expect(defaults.receivedBirthday, birthday);
        expect(defaults.wordCount, words.length);
        if (birthday != null) expect(birthday.dateTime.isUtc, isTrue);
      },
    );
  }
}
