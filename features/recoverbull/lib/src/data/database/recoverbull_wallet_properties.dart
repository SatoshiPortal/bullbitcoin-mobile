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

  /// A new wallet starts without any tested backup, even if a deleted wallet
  /// with the same identifier had one.
  @override
  Future<Result<void, Failure>> prepareWallet(
    WalletPropertyDraft wallet,
  ) async => (await _store(wallet.network).write((
    walletId: wallet.id,
    secretFingerprint: wallet.secretFingerprint?.hex,
    encryptedVaultTested: false,
    physicalBackupTested: false,
    latestEncryptedBackup: null,
    latestPhysicalBackup: null,
  ))).mapErr((failure) => failure);

  RecoverBullWalletBackups _store(Network network) =>
      network.env == NetworkEnv.regtest ? _regtestBackups : _backups;
}
