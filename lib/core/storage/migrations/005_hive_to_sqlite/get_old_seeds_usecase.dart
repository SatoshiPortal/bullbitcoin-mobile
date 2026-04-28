import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_seed.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_wallet.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/old_seed_repository.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/old_wallet_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';

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

      final oldMainnetDefaultWallets = oldWallets
          .where(
            (e) =>
                e.type == OldBBWalletType.main &&
                e.network == OldBBNetwork.Mainnet,
          )
          .toList();

      log.fine(
        'PROGRESS: Found  ${oldMainnetDefaultWallets.length} defaultOldSignerWallets',
      );

      final oldMainnetExternalSignerWallets = oldWallets
          .where(
            (e) =>
                e.type == OldBBWalletType.words &&
                e.network == OldBBNetwork.Mainnet,
          )
          .toList();

      log.fine(
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
      log.shout(
        message: 'Migration failed',
        error: e,
        trace: StackTrace.current,
      );
      rethrow;
    }
  }
}
