import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';

class LoadDefaultMnemonicUsecase {
  final WalletRepository _walletRepository;
  final SeedRepository _seedRepository;

  LoadDefaultMnemonicUsecase({
    required WalletRepository walletRepository,
    required SeedRepository seedRepository,
  })  : _walletRepository = walletRepository,
        _seedRepository = seedRepository;

  Future<List<String>> execute() async {
    try {
      final defaultWallets = await _walletRepository.getWallets(
        onlyDefaults: true,
        onlyBitcoin: true,
        environment: Environment.mainnet,
      );
      if (defaultWallets.isEmpty) {
        throw Exception('No default wallet found');
      }
      // There should only be one default Bitcoin wallet
      final defaultWallet = defaultWallets.first;
      final defaultFingerprint = defaultWallet.masterFingerprint;

      final defaultSeed = await _seedRepository.get(defaultFingerprint);
      final defaultSeedModel = SeedModel.fromEntity(defaultSeed);
      final mnemonicWords = defaultSeedModel.maybeMap(
        mnemonic: (mnemonic) => mnemonic.mnemonicWords,
        orElse: () => throw Exception('Default seed is not a mnemonic seed'),
      );
      return mnemonicWords;
    } catch (e) {
      throw LoadDefaultMnemonicUsecaseException(e.toString());
    }
  }
}

class LoadDefaultMnemonicUsecaseException implements Exception {
  final String message;

  LoadDefaultMnemonicUsecaseException(this.message);
}
