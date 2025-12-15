import 'package:bb_mobile/core_deprecated/storage/migrations/005_hive_to_sqlite/old/entities/old_seed.dart';
import 'package:bb_mobile/core_deprecated/storage/migrations/005_hive_to_sqlite/old/entities/old_wallet.dart';
import 'package:bb_mobile/core_deprecated/storage/migrations/005_hive_to_sqlite/old/old_seed_repository.dart';
import 'package:bb_mobile/core_deprecated/storage/migrations/005_hive_to_sqlite/old/old_wallet_repository.dart';
import 'package:bb_mobile/core_deprecated/utils/logger.dart';

class GetOldSeedsUsecase {
  final OldSeedRepository _oldSeedRepository;
  final OldWalletRepository _oldWalletRepository;
  GetOldSeedsUsecase({
    required OldSeedRepository oldSeedRepository,
    required OldWalletRepository oldWalletRepository,
  }) : _oldSeedRepository = oldSeedRepository,
       _oldWalletRepository = oldWalletRepository;
  // true : successful migration
  // false: migration was not required / success
  // throw: errors
  Future<List<OldSeed>> execute() async {
    try {
      final oldWallets = await _oldWalletRepository.fetch();
      if (oldWallets.isEmpty) return [];

      final oldMainnetDefaultWallets =
          oldWallets
              .where(
                (e) =>
                    e.type == OldBBWalletType.main &&
                    e.network == OldBBNetwork.Mainnet,
              )
              .toList();

      await log.migration(
        level: Level.INFO,
        message:
            'PROGRESS: Found  ${oldMainnetDefaultWallets.length} defaultOldSignerWallets',
      );

      final oldMainnetExternalSignerWallets =
          oldWallets
              .where(
                (e) =>
                    e.type == OldBBWalletType.words &&
                    e.network == OldBBNetwork.Mainnet,
              )
              .toList();

      await log.migration(
        level: Level.INFO,
        message:
            'PROGRESS: Found ${oldMainnetExternalSignerWallets.length} externalOldSignerWallets',
      );

      final oldMainnetSignerWallets =
          oldMainnetDefaultWallets + oldMainnetExternalSignerWallets;
      final oldSeeds = <OldSeed>[];
      for (final wallet in oldMainnetSignerWallets) {
        final seed = await _oldSeedRepository.fetch(
          fingerprint: wallet.mnemonicFingerprint,
        );
        oldSeeds.add(seed);
      }
      return oldSeeds;
    } catch (e) {
      await log.migration(
        level: Level.SEVERE,
        message: 'Migration failed',
        exception: e,
        stackTrace: StackTrace.current,
      );
      rethrow;
    }
  }
}
