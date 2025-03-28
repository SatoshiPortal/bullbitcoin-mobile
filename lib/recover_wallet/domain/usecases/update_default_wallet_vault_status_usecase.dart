import 'package:bb_mobile/_core/domain/repositories/wallet_metadata_repository.dart';

class UpdateDefaultWalletVaultStatusUsecase {
  final WalletMetadataRepository _walletMetadataRepository;

  UpdateDefaultWalletVaultStatusUsecase({
    required WalletMetadataRepository walletMetadataRepository,
  }) : _walletMetadataRepository = walletMetadataRepository;

  Future<void> execute() async {
    final defaultWallet = await _walletMetadataRepository.getDefault();
    await _walletMetadataRepository.store(
      defaultWallet.copyWith(isEncryptedVaultTested: true),
    );
  }
}
