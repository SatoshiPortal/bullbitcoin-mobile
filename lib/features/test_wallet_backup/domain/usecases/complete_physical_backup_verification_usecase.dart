import 'package:bb_mobile/core/wallet/domain/repositories/wallet_metadata_repository.dart';

class CompletePhysicalBackupVerificationUsecase {
  final WalletMetadataRepository walletMetadataRepository;

  CompletePhysicalBackupVerificationUsecase({
    required this.walletMetadataRepository,
  });

  Future<void> execute() async {
    final defaultWallet = await walletMetadataRepository.getDefault();
    await walletMetadataRepository.store(
      defaultWallet.copyWith(
        isPhysicalBackupTested: true,
        lastestPhysicalBackup: DateTime.now(),
      ),
    );
  }
}
