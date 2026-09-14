import 'dart:typed_data';

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/wallet_backup_file_repository.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_vault_from_bip138_file_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_vaults_from_backup_words_usecase.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Metadata extends Mock implements WalletBackupFacade {}

class _Vaults extends Mock implements BullVaultFacade {}

class _Identity extends Mock implements NostrIdentityFacade {}

class _Files extends Mock implements WalletBackupFileRepository {}

class _Parser extends Mock implements BitcoinDescriptorPort {}

/// A public synthetic mnemonic. It holds no funds and must never hold any.
const _mnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon about';

/// The words the originating phone's credential really is: derived from the
/// canonical seed, the one the default wallet holds, with no passphrase.
String _publishedWords() {
  final bytes = Uint8List.fromList(
    bip39.Mnemonic.fromSentence(_mnemonic, bip39.Language.english).seed,
  );
  return BackupCredential.deriveWords(
    Seed.mnemonic(
      mnemonicWords: _mnemonic.split(' '),
      bytes: bytes,
      masterFingerprint: bip32.Bip32Keys.fromSeed(bytes).fingerprintHex,
    ),
  );
}

void main() {
  late RecoverVaultsFromBackupWordsUsecase usecase;

  setUp(() {
    usecase = RecoverVaultsFromBackupWordsUsecase(
      _Metadata(),
      _Vaults(),
      _Identity(),
      RecoverVaultFromBip138FileUsecase(_Vaults(), _Parser(), _Files()),
    );
  });

  test('a mobile seed derives the words its own wallet published', () {
    expect(
      usecase.mobileSeedWords(mnemonic: _mnemonic.split(' ')),
      isA<Ok<String, BackupSettingsFailure>>().having(
        (value) => value.value,
        'derived words',
        _publishedWords(),
      ),
    );
  });

  test('a vault passphrase never changes which backup words are '
      'searched for', () {
    // Creation takes the backup credential from the canonical seed and the
    // vault passphrase only for the signing key, so a passphrase vault
    // publishes under exactly these words. Deriving from the passphrase
    // variant here would search a namespace nothing was ever published in.
    final withoutPassphrase = usecase.mobileSeedWords(
      mnemonic: _mnemonic.split(' '),
    );
    final canonicalRoot = Bip32Derivation.getCanonicalRootXprvFromSeed(
      Uint8List.fromList(
        bip39.Mnemonic.fromSentence(_mnemonic, bip39.Language.english).seed,
      ),
    );
    final passphraseRoot = Bip32Derivation.getCanonicalRootXprvFromSeed(
      Uint8List.fromList(
        bip39.Mnemonic.fromWords(
          words: _mnemonic.split(' '),
          passphrase: 'vault passphrase',
        ).seed,
      ),
    );

    expect(
      canonicalRoot,
      isNot(passphraseRoot),
      reason: 'the two seeds really are different roots',
    );
    expect(
      (withoutPassphrase as Ok<String, BackupSettingsFailure>).value,
      _publishedWords(),
    );
  });

  test('words that are not a mnemonic are refused before any derivation', () {
    expect(
      usecase.mobileSeedWords(mnemonic: const ['not', 'a', 'mnemonic']),
      isA<Err<String, BackupSettingsFailure>>().having(
        (value) => value.failure,
        'failure',
        isA<BackupSettingsInvalidBackupWordsFailure>(),
      ),
    );
  });
}
