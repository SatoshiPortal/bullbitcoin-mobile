import 'package:primitives/primitives.dart';
import 'package:secrets/storage.dart';

import 'recoverbull_wallet_backups.dart';

/// The backup facts of each wallet, in the store of its network family.
final class RecoverBullWalletProperties implements WalletPropertyStore {
  final RecoverBullWalletBackups _backups;
  final RecoverBullWalletBackups _regtestBackups;

  const RecoverBullWalletProperties({
    required this._backups,
    required this._regtestBackups,
  });

  /// A new seed starts without tested wallet properties. Existing secret
  /// members keep matching evidence, while a conflicting identity is refused.
  @override
  Future<Result<void, Failure>> prepareWallet(
    WalletPropertyDraft wallet,
  ) async => (await _store(wallet.network).prepare(
    (
      walletId: wallet.id,
      secretFingerprint: wallet.secretFingerprint?.hex,
      encryptedVaultTested: false,
      physicalBackupTested: false,
      latestEncryptedBackup: null,
      latestPhysicalBackup: null,
    ),
    preserveVerified: wallet.existingSecretMember,
  )).mapErr((failure) => failure);

  RecoverBullWalletBackups _store(Network network) =>
      network.env == NetworkEnv.regtest ? _regtestBackups : _backups;
}
