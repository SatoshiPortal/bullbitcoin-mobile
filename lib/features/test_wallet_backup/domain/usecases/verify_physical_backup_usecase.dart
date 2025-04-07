import 'package:bb_mobile/core/seed/data/models/seed_model.dart' show SeedModel;
import 'package:bb_mobile/core/seed/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_metadata_repository.dart';
import 'package:flutter/foundation.dart';

class VerifyPhysicalBackupUsecase {
  final WalletMetadataRepository walletMetadataRepository;
  final SeedRepository seedRepository;
  VerifyPhysicalBackupUsecase({
    required this.walletMetadataRepository,
    required this.seedRepository,
  });

  Future<bool> execute(List<String> mnemonic) async {
    try {
      final defaultMetadata = await walletMetadataRepository.getDefault();
      final defaultFingerprint = defaultMetadata.masterFingerprint;
      final defaultSeed = await seedRepository.get(defaultFingerprint);

      final defaultSeedModel = SeedModel.fromEntity(defaultSeed);
      final mnemonicWords = defaultSeedModel.maybeMap(
        mnemonic: (mnemonic) => mnemonic.mnemonicWords,
        orElse: () => throw Exception('Default seed is not a mnemonic seed'),
      );

      return mnemonic.length == mnemonicWords.length &&
          List.generate(mnemonic.length, (i) => mnemonic[i] == mnemonicWords[i])
              .every((element) => element);
    } catch (e) {
      debugPrint('$VerifyPhysicalBackupUsecase: $e');
      rethrow;
    }
  }
}
