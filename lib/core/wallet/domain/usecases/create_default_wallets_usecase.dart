import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/data/services/mnemonic_generator.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';

typedef DefaultWalletsResult = ({
  List<Wallet> wallets,
  Set<String> createdWalletIds,
});

class CreateDefaultWalletsUsecase {
  final SeedRepository _seedRepository;
  final SettingsRepository _settingsRepository;
  final MnemonicGenerator _mnemonicGenerator;
  final WalletRepository _wallet;

  CreateDefaultWalletsUsecase({
    required this._seedRepository,
    required this._settingsRepository,
    required this._mnemonicGenerator,
    required WalletRepository walletRepository,
  }) : _wallet = walletRepository;

  Future<DefaultWalletsResult> execute({
    List<String>? mnemonicWords,
    String? passphrase,
  }) async {
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
      if (hasBitcoin && hasLiquid) {
        return (wallets: existing, createdWalletIds: const <String>{});
      }

      // A descriptor wallet can be adopted as a default wallet. It remains
      // pre-existing for metadata conflict handling, even if it was hidden.
      final existingIds = await _wallet.getStoredWalletIds();

      final isGenerated = mnemonicWords == null;
      final mnemonic = mnemonicWords ?? _mnemonicGenerator.generate();
      final DateTime? birthday = isGenerated ? DateTime.now().toUtc() : null;
      final seed = await _seedRepository.createFromMnemonic(
        mnemonicWords: mnemonic,
        passphrase: passphrase,
      );

      final created = <Wallet>[];
      try {
        // Bitcoin creation may reuse an imported descriptor wallet. Do it
        // last so rollback contains only wallets created by this operation.
        if (!hasLiquid) {
          created.add(
            await _wallet.createWallet(
              seed: seed,
              network: liquidNetwork,
              scriptType: scriptType,
              provenance: WalletProvenance.defaultSeed,
              isDefault: true,
              birthday: birthday,
            ),
          );
        }
        if (!hasBitcoin) {
          created.add(
            await _wallet.createWallet(
              seed: seed,
              network: bitcoinNetwork,
              scriptType: scriptType,
              provenance: WalletProvenance.defaultSeed,
              isDefault: true,
              birthday: birthday,
            ),
          );
        }
      } catch (_) {
        for (final wallet in created) {
          if (existingIds.contains(wallet.id)) continue;
          try {
            await _wallet.deleteWallet(walletId: wallet.id);
          } catch (e, stackTrace) {
            log.severe(
              message: 'CreateDefaultWalletsUsecase: rollback failed',
              error: e.runtimeType,
              trace: stackTrace,
            );
          }
        }
        rethrow;
      }

      return (
        wallets: List<Wallet>.unmodifiable([...existing, ...created]),
        createdWalletIds: Set.unmodifiable(
          created
              .map((wallet) => wallet.id)
              .where((id) => !existingIds.contains(id)),
        ),
      );
    } catch (_) {
      throw CreateDefaultWalletsException('Default wallet creation failed');
    }
  }
}

class CreateDefaultWalletsException extends BullException {
  CreateDefaultWalletsException(super.message);
}
