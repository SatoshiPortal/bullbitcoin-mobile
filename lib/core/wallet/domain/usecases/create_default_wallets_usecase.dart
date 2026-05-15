import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/data/services/mnemonic_generator.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class CreateDefaultWalletsUsecase {
  final SeedRepository _seedRepository;
  final SettingsRepository _settingsRepository;
  final MnemonicGenerator _mnemonicGenerator;
  final WalletRepository _wallet;

  CreateDefaultWalletsUsecase({
    required SeedRepository seedRepository,
    required SettingsRepository settingsRepository,
    required MnemonicGenerator mnemonicGenerator,
    required WalletRepository walletRepository,
  }) : _seedRepository = seedRepository,
       _settingsRepository = settingsRepository,
       _mnemonicGenerator = mnemonicGenerator,
       _wallet = walletRepository;

  Future<List<Wallet>> execute({
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
      if (hasBitcoin && hasLiquid) return existing;

      final Seed seed;
      DateTime? birthday;
      if (existing.isNotEmpty) {
        final missing = !hasBitcoin ? 'bitcoin' : 'liquid';
        log.severe(
          message: 'CreateDefaultWalletsUsecase: partial default set detected',
          error: CreateDefaultWalletsException('missing $missing default wallet'),
          trace: StackTrace.current,
        );
        seed = await _seedRepository.get(existing.first.masterFingerprint);
      } else {
        final isGenerated = mnemonicWords == null;
        final mnemonic = mnemonicWords ?? _mnemonicGenerator.generate();
        if (isGenerated) birthday = DateTime.now().toUtc();
        seed = await _seedRepository.createFromMnemonic(
          mnemonicWords: mnemonic,
          passphrase: passphrase,
        );
      }

      final tasks = <Future<Wallet>>[];
      if (!hasBitcoin) {
        tasks.add(
          _wallet.createWallet(
            seed: seed,
            network: bitcoinNetwork,
            scriptType: scriptType,
            isDefault: true,
            birthday: birthday,
          ),
        );
      }
      if (!hasLiquid) {
        tasks.add(
          _wallet.createWallet(
            seed: seed,
            network: liquidNetwork,
            scriptType: scriptType,
            isDefault: true,
            birthday: birthday,
          ),
        );
      }

      final newWallets = await Future.wait(tasks);
      return [...existing, ...newWallets];
    } catch (e) {
      throw CreateDefaultWalletsException(e.toString());
    }
  }
}

class CreateDefaultWalletsException extends BullException {
  CreateDefaultWalletsException(super.message);
}
