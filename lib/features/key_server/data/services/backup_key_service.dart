import 'package:bb_mobile/core/seed/domain/repositories/seed_repository.dart'
    show SeedRepository;
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/bip85_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_metadata_repository.dart'
    show WalletMetadataRepository;

class BackupKeyService {
  final SeedRepository _seedRepository;
  final WalletMetadataRepository _walletMetadataRepository;

  BackupKeyService({
    required SeedRepository seedRepository,
    required WalletMetadataRepository walletMetadataRepository,
  })  : _seedRepository = seedRepository,
        _walletMetadataRepository = walletMetadataRepository;

  Future<String> deriveBackupKeyFromDefaultSeed({
    required String? path,
  }) async {
    if (path == null) throw 'Missing bip85 path';
    final defaultMetadata = await _walletMetadataRepository.getDefault();
    final defaultSeed =
        await _seedRepository.get(defaultMetadata.masterFingerprint);
    final xprv = Bip32Derivation.getXprvFromSeed(
      defaultSeed.bytes,
      defaultMetadata.network,
    );

    return Bip85Derivation.deriveBackupKey(xprv, path);
  }
}
