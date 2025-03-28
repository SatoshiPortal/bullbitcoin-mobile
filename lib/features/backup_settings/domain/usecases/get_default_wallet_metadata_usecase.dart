
import 'package:bb_mobile/core/wallet/domain/entity/wallet_metadata.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_metadata_repository.dart';

class GetDefaultWalletMetadataUsecase {
  final WalletMetadataRepository walletMetadataRepository;

  GetDefaultWalletMetadataUsecase({
    required this.walletMetadataRepository,
  });

  Future<WalletMetadata> execute() async {
    try {
      return await walletMetadataRepository.getDefault();
    } catch (e) {
      throw Exception('Failed to get default wallet metadata: $e');
    }
  }
}
