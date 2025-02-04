import 'package:bb_mobile/features/wallet/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/features/wallet/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/features/wallet/domain/services/seed_generator.dart';
import 'package:bb_mobile/features/wallet/domain/services/wallet_repository_manager.dart';

class CreateDefaultWalletsUseCase {
  final SeedGenerator _seedGenerator;
  // TODO: final NetworkEnvironmentRepository _networkEnvironmentRepository;
  final WalletMetadataRepository _walletMetadataRepository;
  final WalletRepositoryManager _walletRepositoryManager;

  CreateDefaultWalletsUseCase({
    required SeedGenerator seedGenerator,
    required WalletMetadataRepository walletMetadataRepository,
    required WalletRepositoryManager walletRepositoryManager,
  })  : _seedGenerator = seedGenerator,
        _walletMetadataRepository = walletMetadataRepository,
        _walletRepositoryManager = walletRepositoryManager;

  Future<void> execute() async {
    // TODO: final environment = await _networkEnvironmentRepository.getNetwork();
    final seed = await _seedGenerator.newSeed();
  }
}
