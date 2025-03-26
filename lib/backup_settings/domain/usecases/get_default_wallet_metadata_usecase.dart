import 'package:bb_mobile/_core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/_core/domain/repositories/wallet_metadata_repository.dart';

class GetDefaultWalletMetadataUsecase {
  final WalletMetadataRepository walletMetadataRepository;

  GetDefaultWalletMetadataUsecase({
    required this.walletMetadataRepository,
  });

  Future<WalletMetadata> execute() async {
    try {
      final defaultMetadata = await walletMetadataRepository.getDefault();
      if (defaultMetadata == null) {
        throw Exception('No default wallet metadata found');
      }

      return defaultMetadata;
    } catch (e) {
      throw Exception('Failed to get default wallet metadata: $e');
    }
  }
}
