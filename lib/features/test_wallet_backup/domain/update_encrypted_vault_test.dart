import 'package:bb_mobile/core/wallet/domain/repositories/wallet_metadata_repository.dart';

class UpdateEncryptedVaultTest {
  final WalletMetadataRepository walletMetadataRepository;
  UpdateEncryptedVaultTest({
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
