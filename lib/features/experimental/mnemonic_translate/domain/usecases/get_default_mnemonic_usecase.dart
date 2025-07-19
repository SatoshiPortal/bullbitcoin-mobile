import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class GetDefaultMnemonicUsecase {
  final WalletRepository _walletRepository;
  final SeedRepository _seedRepository;

  GetDefaultMnemonicUsecase({
    required WalletRepository walletRepository,
    required SeedRepository seedRepository,
  }) : _walletRepository = walletRepository,
       _seedRepository = seedRepository;

  Future<(List<String>, String?)> execute() async {
    try {
      final defaultWallets = await _walletRepository.getWallets(
        onlyDefaults: true,
        onlyBitcoin: true,
        environment: Environment.mainnet,
      );

      if (defaultWallets.isEmpty) throw 'No default wallet found';

      final defaultWallet = defaultWallets.first;
      final defaultFingerprint = defaultWallet.masterFingerprint;
      final defaultSeed = await _seedRepository.get(defaultFingerprint);

      final defaultSeedModel = SeedModel.fromEntity(defaultSeed);
      final (mnemonicWords, passphrase) = switch (defaultSeedModel) {
        MnemonicSeedModel(:final mnemonicWords, :final passphrase) => (
          mnemonicWords,
          passphrase,
        ),
        _ => throw 'Default seed is not a mnemonic seed',
      };

      return (mnemonicWords, passphrase);
    } catch (e) {
      throw GetDefaultMnemonicException(e.toString());
    }
  }
}

class GetDefaultMnemonicException implements Exception {
  final String message;

  GetDefaultMnemonicException(this.message);
}
