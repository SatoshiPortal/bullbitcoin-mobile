import 'package:bb_mobile/_core/domain/repositories/seed_repository.dart'
    show SeedRepository;
import 'package:bb_mobile/_core/domain/repositories/wallet_metadata_repository.dart'
    show WalletMetadataRepository;
import 'package:bb_mobile/_utils/bip32_derivation.dart';
import 'package:bb_mobile/_utils/bip85_derivation.dart';
import 'package:bb_mobile/key_server/domain/model/errors/key_server_error.dart';
import 'package:bb_mobile/key_server/domain/services/backup_key_service.dart';

class BackupKeyServiceImpl implements BackupKeyService {
  final SeedRepository _seedRepository;
  final WalletMetadataRepository _walletMetadataRepository;

  BackupKeyServiceImpl({
    required SeedRepository seedRepository,
    required WalletMetadataRepository walletMetadataRepository,
  })  : _seedRepository = seedRepository,
        _walletMetadataRepository = walletMetadataRepository;
  @override
  Future<String> deriveBackupKeyFromDefaultSeed({
    required String? path,
  }) async {
    if (path == null) throw const Bip85PathMissingError();
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
