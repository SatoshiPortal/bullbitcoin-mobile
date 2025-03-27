import 'package:bb_mobile/_core/domain/repositories/wallet_metadata_repository.dart';

class CheckForTorInitializationOnStartupUsecase {
  final WalletMetadataRepository walletMetadataRepository;

  CheckForTorInitializationOnStartupUsecase({
    required this.walletMetadataRepository,
  });

  Future<bool> execute() async {
    final defaultWallet = await walletMetadataRepository.getDefault();
    return defaultWallet.isTorEnabledOnStartup;
  }
}
