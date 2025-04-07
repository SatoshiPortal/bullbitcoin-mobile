import 'package:bb_mobile/core/wallet/domain/repositories/wallet_metadata_repository.dart';

class CompleteEncryptedVaultVerificationUsecase {
  final WalletMetadataRepository walletMetadataRepository;
  CompleteEncryptedVaultVerificationUsecase({
    required this.walletMetadataRepository,
  });

  Future<void> execute() async {
    final defaultWallet = await walletMetadataRepository.getDefault();
    await walletMetadataRepository.store(
      defaultWallet.copyWith(
        isEncryptedVaultTested: true,
      ),
    );
  }
}
