import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_metadata_repository.dart';

class LoadDefaultMnemonicUsecase {
  final WalletMetadataRepository walletMetadataRepository;
  final SeedRepository seedRepository;

  LoadDefaultMnemonicUsecase({
    required this.walletMetadataRepository,
    required this.seedRepository,
  });
  Future<List<String>> execute() async {
    final defaultMetadata = await walletMetadataRepository.getDefault();
    final defaultFingerprint = defaultMetadata.masterFingerprint;

    final defaultSeed = await seedRepository.get(defaultFingerprint);
    final defaultSeedModel = SeedModel.fromEntity(defaultSeed);
    final mnemonicWords = defaultSeedModel.maybeMap(
      mnemonic: (mnemonic) => mnemonic.mnemonicWords,
      orElse: () => throw Exception('Default seed is not a mnemonic seed'),
    );
    return mnemonicWords;
  }
}
