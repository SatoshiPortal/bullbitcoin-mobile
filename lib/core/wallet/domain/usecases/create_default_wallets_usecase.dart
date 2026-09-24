import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:secrets/secrets.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/utils/result.dart';

/// Creates the default Bitcoin and Liquid wallets from one secret: generated, or imported from words.
///
/// ⚠️ **Default wallets never carry a BIP39 passphrase — by rule, and by signature: this use case takes none.** Several paths are only correct because the default secret is passphrase-less, and each would regress if one were allowed here:
///
/// - **Liquid.** lwk derives from the words alone (lwk_signer 0.18.0 hard-codes `to_seed("")`), so the Liquid default would belong to the passphrase-less sibling while the Bitcoin default belonged to the passphrase secret: two defaults on two different seeds, and a passphrase that protects no Liquid funds.
/// - **RecoverBull.** The vault carries the words only, so restoring it gives the passphrase-less wallet — a different Bitcoin wallet — while the vault key is derived from the seed *with* the passphrase.
/// - **Swap key.** Derived from the default Bitcoin wallet; the package sends the passphrase to boltz, released builds up to v6.13.4 did not, so a passphrase default would re-derive a different swap key after a restore and lose sight of earlier swaps.
/// - **BIP85 children.** Derived from the default wallet's seed, passphrase included, so every child would change with it.
/// - **Physical backup check.** `verifyWords` compares the words only; the passphrase would go unverified.
///
/// Supporting a passphrase on the default wallets therefore starts with lwk supporting one, then a decision for each path above. Until then a passphrase secret is an imported, non-default wallet (`ImportWalletUsecase`, `isDefault: false`).
class CreateDefaultWalletsUsecase {
  final Secrets _secrets;
  final SettingsRepository _settingsRepository;
  final WalletRepository _wallet;

  CreateDefaultWalletsUsecase({
    required this._secrets,
    required this._settingsRepository,
    required WalletRepository walletRepository,
  }) : _wallet = walletRepository;

  Future<List<Wallet>> execute({List<String>? mnemonicWords}) async {
    try {
      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;

      const scriptType = ScriptType.bip84;
      final bitcoinNetwork = environment.isMainnet
          ? Network.bitcoinMainnet
          : Network.bitcoinTestnet;
      final liquidNetwork = environment.isMainnet
          ? Network.liquidMainnet
          : Network.liquidTestnet;

      final existing = await _wallet.getWallets(
        onlyDefaults: true,
        environment: environment,
      );
      final hasBitcoin = existing.any((w) => w.network.isBitcoin);
      final hasLiquid = existing.any((w) => w.network.isLiquid);
      if (hasBitcoin && hasLiquid) return existing;

      final isGenerated = mnemonicWords == null;
      final DateTime? birthday = isGenerated ? DateTime.now().toUtc() : null;
      // Generation and import both happen inside the package; the words never come back here.
      final secret = switch (isGenerated
          ? await _secrets.generate()
          : await _secrets.import(words: mnemonicWords)) {
        Ok(:final value) => value,
        Err(:final failure) => throw StateError(
          'could not create the default secret: ${failure.runtimeType}',
        ),
      };

      final created = <Wallet>[];
      try {
        if (!hasBitcoin) {
          created.add(
            await _wallet.createWallet(
              secret: secret,
              network: bitcoinNetwork,
              scriptType: scriptType,
              isDefault: true,
              birthday: birthday,
            ),
          );
        }
        if (!hasLiquid) {
          created.add(
            await _wallet.createWallet(
              secret: secret,
              network: liquidNetwork,
              scriptType: scriptType,
              isDefault: true,
              birthday: birthday,
            ),
          );
        }
      } catch (_) {
        for (final wallet in created) {
          try {
            await _wallet.deleteWallet(walletId: wallet.id);
          } catch (e, stackTrace) {
            log.severe(
              message: 'CreateDefaultWalletsUsecase: rollback failed',
              error: e,
              trace: stackTrace,
            );
          }
        }
        rethrow;
      }

      return [...existing, ...created];
    } catch (e) {
      throw CreateDefaultWalletsException(e.toString());
    }
  }
}

class CreateDefaultWalletsException extends BullException {
  CreateDefaultWalletsException(super.message);
}
