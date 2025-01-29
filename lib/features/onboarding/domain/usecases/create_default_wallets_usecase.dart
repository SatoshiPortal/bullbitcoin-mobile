import 'package:bb_mobile/features/wallet/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/features/wallet/domain/services/mnemonic_generator.dart';
import 'package:bb_mobile/features/wallet/domain/services/wallet_repository_manager.dart';

class CreateDefaultWalletsUseCase {
  final MnemonicGenerator _mnemonicGenerator;
  final WalletMetadataRepository _walletMetadataRepository;
  final WalletRepositoryManager _walletRepositoryManager;

  CreateDefaultWalletsUseCase({
    required MnemonicGenerator mnemonicGenerator,
    required WalletMetadataRepository walletMetadataRepository,
    required WalletRepositoryManager walletRepositoryManager,
  })  : _mnemonicGenerator = mnemonicGenerator,
        _walletMetadataRepository = walletMetadataRepository,
        _walletRepositoryManager = walletRepositoryManager;

  Future<void> execute() async {
    final mnemonic = await _mnemonicGenerator.generateMnemonic();
  }
}
