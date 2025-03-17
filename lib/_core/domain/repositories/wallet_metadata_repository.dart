import 'package:bb_mobile/_core/domain/entities/seed.dart';
import 'package:bb_mobile/_core/domain/entities/wallet_metadata.dart';

abstract class WalletMetadataRepository {
  Future<WalletMetadata> deriveFromSeed({
    required Seed seed,
    required Network network,
    required ScriptType scriptType,
    String label,
    bool isDefault,
  });
  Future<WalletMetadata> deriveFromXpub({
    required String xpub,
    required Network network,
    required ScriptType scriptType,
    String label,
  });
  Future<void> store(
    WalletMetadata metadata,
  );
  Future<WalletMetadata?> get(String walletId);
  Future<List<WalletMetadata>> getAll();
  Future<void> delete(String walletId);
  Future<WalletMetadata> getDefault();
}
