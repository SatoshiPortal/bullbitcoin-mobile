import 'package:bb_mobile/core/seed/data/models/seed_model.dart'
    show MnemonicSeedModel, SeedModel;
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class VerifyPhysicalBackupUsecase {
  final WalletRepository _walletRepository;
  final SeedRepository _seedRepository;
  VerifyPhysicalBackupUsecase({
    required WalletRepository walletRepository,
    required SeedRepository seedRepository,
  }) : _walletRepository = walletRepository,
       _seedRepository = seedRepository;

  Future<bool> execute(List<String> mnemonic) async {
    try {
      final defaultWallets = await _walletRepository.getWallets(
        onlyDefaults: true,
        onlyBitcoin: true,
        environment: Environment.mainnet,
      );
      if (defaultWallets.isEmpty) {
        throw Exception('No default wallet found');
      }
      final defaultWallet = defaultWallets.first;
      final defaultFingerprint = defaultWallet.masterFingerprint;
      final defaultSeed = await _seedRepository.get(defaultFingerprint);

      final defaultSeedModel = SeedModel.fromEntity(defaultSeed);
      final mnemonicWords = switch (defaultSeedModel) {
        MnemonicSeedModel(:final mnemonicWords) => mnemonicWords,
        _ => throw Exception('Default seed is not a mnemonic seed'),
      };

      return mnemonic.length == mnemonicWords.length &&
          List.generate(
            mnemonic.length,
            (i) => mnemonic[i] == mnemonicWords[i],
          ).every((element) => element);
    } catch (e) {
      log.severe('$VerifyPhysicalBackupUsecase: $e', trace: StackTrace.current);
      rethrow;
    }
  }
}
